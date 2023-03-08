import StorageManagerAuthError from './helpers';

export default class Pool {
    constructor(mgr, name) {
        this.mgr = mgr;
        this.name = name;
    }

    static async create(mgr, name, distribute_groups, opts) {
        return await mgr.httpPost(`/api/v1/pools`, {
            name: name,
            distribute_groups: distribute_groups,
            no_start: opts["no_start"] !== undefined ? opts["no_start"] : false,
            distribute: opts["distribute"] !== undefined ? opts["distribute"] : false,
            pool_id: opts["pool_id"] !== undefined ? opts["pool_id"] : "",
            auto_add_nodes: opts["auto_add_nodes"] !== undefined ? opts["auto_add_nodes"] : false,
            options: opts["options"] !== undefined ? opts["options"] : {},
        })
    }

    static async list(mgr, state=false) {
        return await mgr.httpGet(`/api/v1/pools?state=${state ? 1 : 0}`)
    }

    async get(state=false) {
        return await this.mgr.httpGet(
            `/api/v1/pools/${this.name}?state=${state ? 1 : 0}`
        )
    }

    async start() {
        return await this.mgr.httpPost(
            `/api/v1/pools/${this.name}/start`, {}
        )
    }

    async stop() {
        return await this.mgr.httpPost(
            `/api/v1/pools/${this.name}/stop`, {}
        )
    }

    async rename(newName) {
        return this.mgr.httpPost(
            `/api/v1/pools/${this.name}/rename`,
            {new_name: newName}
        )
    }
    
    async delete() {
        return this.mgr.httpDelete(
            `/api/v1/pools/${this.name}`
        )
    }
}
