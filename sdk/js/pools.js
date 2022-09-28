import StorageManagerAuthError from './helpers';
import Volume from './volumes';

export default class Pool {
    constructor(mgr, name) {
        this.mgr = mgr;
        this.name = name;
    }

    static async create(mgr, name) {
        const response = await fetch(
            `${mgr.url}/api/v1/pools`,
            {
                method: "POST",
                headers: {
                    ...mgr.authHeaders(),
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({name: name})
            }
        );
        const data = await response.json();
        if (data.error) {
            throw new Error(data.error);
        }

        return data;
    }

    static async list(mgr) {
        const response = await fetch(
            mgr.url + '/api/v1/pools',
            {
                headers: {
                    ...mgr.authHeaders()
                }
            }
        );

        return await response.json();
    }

    async listVolumes(state) {
        return await Volume.list(this.mgr, this.name, state);
    }

    async delete() {
        const response = await fetch(
            `${this.mgr.url}/api/v1/pools/${this.name}`,
            {
                method: "DELETE",
                headers: {
                    ...this.mgr.authHeaders()
                }
            }
        );

        if (response.status != 204) {
            throw new Error((await response.json()).error);
        }
        return;
    }

    volume(name) {
        return new Volume(this.mgr, this.name, name);
    }
}
