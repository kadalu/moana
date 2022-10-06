export default class StorageManagerAuthError extends Error {
    constructor(message) {
        super(message);
        this.name = this.constructor.name;
    }
}
