export default class Node {
    constructor(mgr, name) {
        this.mgr = mgr;
        this.name = name;
    }

    static async add(mgr, name, endpoint="") {
        return await mgr.httpPost(
            `/api/v1/nodes`,
            {name: name, endpoint: endpoint}
        )
    }

    static async list(mgr, state=false) {
        return await mgr.httpGet(`/api/v1/nodes?state=${state ? 1 : 0}`)
    }

    async get(state=false) {
        return await this.mgr.httpGet(
            `/api/v1/nodes/${this.name}?state=${state ? 1 : 0}`
        )
    }

    async remove() {
        return this.mgr.httpDelete(
            `/api/v1/nodes/${this.name}`
        )
    }
}
