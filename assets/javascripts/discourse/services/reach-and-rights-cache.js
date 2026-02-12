import Service, { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";

const CACHE_TTL = 600000; // 10 Minuten in Millisekunden

export default class ReachAndRightsCache extends Service {
  @service messageBus;

  @tracked _cacheVersion = 0;
  _cache = new Map();
  _promises = new Map();

  constructor() {
    super(...arguments);
    this.messageBus.subscribe("/reach-and-rights/stats", (msg) => {
      if (msg && msg.updates) {
        msg.updates.forEach((update) => this.updateStats(update));
      } else if (msg) {
        this.updateStats(msg);
      }
    });
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.messageBus.unsubscribe("/reach-and-rights/stats");
  }

  updateStats(stats) {
    const categoryId = parseInt(stats.category_id, 10);
    if (isNaN(categoryId)) {
      return;
    }
    const entry = this._cache.get(categoryId);

    const newTotals = {
      3: stats.watching_count,
      4: stats.watching_first_post_count,
      total_reach: stats.reach_count,
    };

    if (entry) {
      entry.data = {
        ...entry.data,
        category_notification_totals: {
          ...(entry.data.category_notification_totals || {}),
          ...newTotals,
        },
      };
      entry.timestamp = Date.now();
    } else {
      this._cache.set(categoryId, {
        data: {
          category_id: categoryId,
          category_notification_totals: newTotals,
        },
        timestamp: Date.now(),
      });
    }
    this._cacheVersion++;
  }

  async getPermissions(rawId, force = false) {
    const categoryId = parseInt(rawId, 10);
    if (isNaN(categoryId)) {
      return null;
    }
    const entry = this._cache.get(categoryId);
    const now = Date.now();

    // Check if entry exists and has detailed group_permissions
    const isDetailed = !!entry?.data?.group_permissions;

    if (!force && entry && isDetailed && now - entry.timestamp < CACHE_TTL) {
      return entry.data;
    }

    if (!force && this._promises.has(categoryId)) {
      return this._promises.get(categoryId);
    }

    const promise = ajax(`/c/${categoryId}/reach-and-rights`)
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

  setPermissions(rawId, data) {
    const categoryId = parseInt(rawId, 10);
    if (isNaN(categoryId) || !data || Object.keys(data).length === 0) {
      return;
    }
    const entry = this._cache.get(categoryId);
    if (entry) {
      entry.data = { ...entry.data, ...data };
      entry.timestamp = Date.now();
    } else {
      this._cache.set(categoryId, {
        data,
        timestamp: Date.now(),
      });
    }
    this._cacheVersion++;
  }

  clearNotify() {
    this._cache.clear();
  }
}
