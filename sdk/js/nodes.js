export default class Node {
    constructor(mgr, pool_name, name) {
        this.mgr = mgr;
        this.pool_name = pool_name;
        this.name = name;
    }

    static async add(mgr, pool_name, name, endpoint="") {
        return await mgr.httpPost(
            `/api/v1/pools/${pool_name}/nodes`,
            {name: name, endpoint: endpoint}
        )
    }

    static async list(mgr, pool_name, state=false) {
        return await mgr.httpGet(`/api/v1/pools/${pool_name}/nodes?state=${state ? 1 : 0}`)
    }

    async get(state=false) {
        return await this.mgr.httpGet(
            `/api/v1/pools/${this.pool_name}/nodes/${this.name}?state=${state ? 1 : 0}`
        )
    }

    async remove() {
        return this.mgr.httpDelete(
            `/api/v1/pools/${this.pool_name}/nodes/${this.name}`
        )
    }
}
