import Volume from './volumes';
import Node from './nodes';

export default class Pool {
    constructor(mgr, name) {
        this.mgr = mgr;
        this.name = name;
    }

    static async create(mgr, name) {
        return await mgr.httpPost('/api/v1/pools', {name: name})
    }

    static async list(mgr) {
        return await mgr.httpGet('/api/v1/pools')
    }

    async listVolumes(state=false) {
        return await Volume.list(this.mgr, this.name, state);
    }

    async delete() {
        return await mgr.httpDelete(`/api/v1/pools/${this.name}`)
    }

    volume(name) {
        return new Volume(this.mgr, this.name, name);
    }

    node(name) {
        return new Node(this.mgr, this.name, name);
    }

    async addNode(name, endpoint="") {
        return await Node.add(this.mgr, this.name, name, endpoint);
    }

    async listNodes(state=false) {
        return await Node.list(this.mgr, this.name, state);
    }

    async rename(newName) {
        return this.mgr.httpPost(
            `/api/v1/pools/${this.name}/rename`,
            {new_pool_name: newName}
        )
    }
}
