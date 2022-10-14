export default class User {
    constructor(mgr, username) {
        this.mgr = mgr;
        this.username = username;
    }

    static async create(mgr, username, password, fullName="") {
        return await mgr.httpPost('/api/v1/users', {
            name: fullName, username: username, password: password
        })
    }

    static async hasUsers(mgr) {
        return await mgr.httpGet('/api/v1/user-exists', true)
    }
}
