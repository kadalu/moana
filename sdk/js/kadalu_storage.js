import StorageManagerAuthError from './helpers';
import Pool from './pools';

export default class StorageManager {
    constructor(url) {
        this.url = url;
        this.user_id = "";
        this.api_key_id = "";
        this.token = "";
    }

    static fromToken(url, user_id, api_key_id, token) {
        const mgr = new StorageManager(url);
        mgr.user_id = user_id;
        mgr.api_key_id = api_key_id;
        mgr.token = token;

        return mgr;
    }

    authHeaders() {
        if (this.token != "") {
            return {
                "Authorization": `Bearer ${this.token}`,
                "X-User-ID": this.user_id
            }
        }

        return {}
    }

    async generateApiKey(username, password) {
        var response = await fetch(
            `${this.url}/api/v1/users/${username}/api-keys`,
            {
                method: "POST",
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({password: password})
            }
        );

        const data = await response.json();
        if (data.error) {
            throw new Error(data.error);
        }

        return data;
    }

    static async login(url, username, password) {
        const mgr = new StorageManager(url);
        const data = await mgr.generateApiKey(username, password)
        mgr.user_id = data.user_id;
        mgr.api_key_id = data.id;
        mgr.token = data.token;

        return mgr;
    }
    
    async logout() {
        if (this.api_key_id == "") {
            return;
        }
        const response = await fetch(
            `${this.url}/api/v1/api-keys/${this.api_key_id}`,
            {
                method: "DELETE",
                headers: {
                    ...this.authHeaders()
                }
            }
        );

        if (response.status != 204) {
            throw new Error((await response.json()).error);
        }
        this.api_key_id = '';
        this.user_id = '';
        this.token = '';

        return;
    }

    async listPools() {
        return await Pool.list(this);
    }

    pool(name) {
        return new Pool(this, name);
    }

    async createPool(name) {
        return await Pool.create(this, name);
    }
}
