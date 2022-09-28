import StorageManagerAuthError from './helpers';

export default class Volume {
    constructor(mgr, pool_name, name) {
        this.mgr = mgr;
        this.pool_name = pool_name;
        this.name = name;
    }

    static async list(mgr, pool_name, state) {
        state = state === undefined ? false : state;
        const response = await fetch(
            `${mgr.url}/api/v1/pools/${pool_name}/volumes?state=${state ? 1 : 0}`,
            {
                headers: {
                    ...mgr.authHeaders()
                }
            }
        );

        return await response.json();
    }

    async get(state) {
        state = state === undefined ? false : state;
        const response = await fetch(
            `${this.mgr.url}/api/v1/pools/${this.pool_name}/volumes/${this.name}?state=${state ? 1 : 0}`,
            {
                headers: {
                    ...this.mgr.authHeaders()
                }
            }
        );

        return await response.json();
    }

    async startOrStop(action) {
        const response = await fetch(
            `${this.mgr.url}/api/v1/pools/${this.pool_name}/volumes/${this.name}/${action}`,
            {
                method: "POST",
                headers: {
                    ...this.mgr.authHeaders()
                }
            }
        );

        return await response.json();
    }

    async start() {
        return await this.startOrStop("start");
    }

    async stop() {
        return await this.startOrStop("stop");
    }

    async delete() {
        const response = await fetch(
            `${this.mgr.url}/api/v1/pools/${this.pool_name}/volumes/${this.name}`,
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
}
