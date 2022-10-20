import StorageManagerAuthError from './helpers';

export default class Volume {
    constructor(mgr, pool_name, name) {
        this.mgr = mgr;
        this.pool_name = pool_name;
        this.name = name;
    }

    static async create(mgr, pool_name, name, distribute_groups, opts) {
        return await mgr.httpPost(`/api/v1/pools/${pool_name}/volumes`, {
            name: name,
            distribute_groups: distribute_groups,
            no_start: opts["no_start"] !== undefined ? opts["no_start"] : false,
            volume_id: opts["volume_id"] !== undefined ? opts["volume_id"] : "",
            auto_create_pool: opts["auto_create_pool"] !== undefined ? opts["auto_create_pool"] : false,
            auto_add_nodes: opts["auto_add_nodes"] !== undefined ? opts["auto_add_nodes"] : false,
            options: opts["options"] !== undefined ? opts["options"] : {},
        })
    }

    static async list(mgr, pool_name, state=false) {
        return await mgr.httpGet(`/api/v1/pools/${pool_name}/volumes?state=${state ? 1 : 0}`)
    }

    async get(state=false) {
        return await this.mgr.httpGet(
            `/api/v1/pools/${this.pool_name}/volumes/${this.name}?state=${state ? 1 : 0}`
        )
    }

    async start() {
        return await this.mgr.httpPost(
            `/api/v1/pools/${this.pool_name}/volumes/${this.name}/start`, {}
        )
    }

    async stop() {
        return await this.mgr.httpPost(
            `/api/v1/pools/${this.pool_name}/volumes/${this.name}/stop`, {}
        )
    }

    async delete() {
        return this.mgr.httpDelete(
            `/api/v1/pools/${this.pool_name}/volumes/${this.name}`
        )
    }
}
