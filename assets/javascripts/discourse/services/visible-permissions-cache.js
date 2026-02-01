import Service from "@ember/service";
import { ajax } from "discourse/lib/ajax";

const CACHE_TTL = 600000; // 10 Minuten in Millisekunden

export default class VisiblePermissionsCache extends Service {
  _cache = new Map();
  _promises = new Map();

  async getPermissions(categoryId, force = false) {
    const entry = this._cache.get(categoryId);
    const now = Date.now();

    if (!force && entry && (now - entry.timestamp < CACHE_TTL)) {
      return entry.data;
    }

    if (!force && this._promises.has(categoryId)) {
      return this._promises.get(categoryId);
    }

    const promise = ajax(`/c/${categoryId}/permissions.json`)
      .then((data) => {
        this.setPermissions(categoryId, data);
        return data;
      })
      .finally(() => {
        this._promises.delete(categoryId);
      });

    this._promises.set(categoryId, promise);
    return promise;
  }

  setPermissions(categoryId, data) {
    this._cache.set(categoryId, {
      data,
      timestamp: Date.now(),
    });
  }

  clearNotify() {
    this._cache.clear();
  }
}