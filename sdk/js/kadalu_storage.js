import StorageManagerAuthError from './helpers';
import Pool from './pools';
import User from './users';

export default class StorageManager {
    constructor(url) {
        this.url = url;
        this.user_id = "";
        this.api_key_id = "";
        this.token = "";
    }

    async httpPost(urlPath, body) {
        const response = await fetch(
            `${this.url}${urlPath}`,
            {
                method: "POST",
                headers: {
                    ...this.authHeaders(),
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(body)
            }
        );

        if (response.status == 401 || response.status == 403) {
            throw new StorageManagerAuthError((await response.json()).error);
        }

        const data = await response.json();
        if (data.error) {
            throw new Error(data.error);
        }

        return data;
    }

    async httpGet(urlPath, existsCheck=false) {
        const response = await fetch(
            `${this.url}${urlPath}`,
            {
                headers: {
                    ...this.authHeaders(),
                    'Content-Type': 'application/json'
                }
            }
        );

        if (response.status == 401 || response.status == 403) {
            throw new StorageManagerAuthError((await response.json()).error);
        }

        if (existsCheck) {
            return response.status == 200 ? true : false;
        }

        const data = await response.json();
        if (data.error) {
            throw new Error(data.error);
        }

        return data;
    }

    async httpDelete(urlPath) {
        const response = await fetch(
            `${this.url}${urlPath}`,
            {
                method: "DELETE",
                headers: {
                    ...this.authHeaders(),
                    'Content-Type': 'application/json'
                }
            }
        );

        if (response.status == 401 || response.status == 403) {
            throw new StorageManagerAuthError((await response.json()).error);
        }

        if (response.status !== 204) {
            const data = await response.json();
            if (data.error) {
                throw new Error(data.error);
            }
        }

        return;
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
        return await this.httpPost(
            `/api/v1/users/${username}/api-keys`, {password: password}
        )
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

        await this.httpDelete(`/api/v1/api-keys/${this.api_key_id}`)
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

    async createUser(username, password, fullName="") {
        return await User.create(this, username, password, fullName);
    }

    async hasUsers() {
        return await User.hasUsers()
    }

    user(username) {
        return new User(this, username)
    }
}
