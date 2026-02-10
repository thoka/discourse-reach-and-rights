import Component from "@glimmer/component";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";
import { service } from "@ember/service";
import ReachAndRightsTable from "../reach-and-rights/table";

export default class ReachAndRightsDetails extends Component {
  @service siteSettings;

  get data() {
    return this.args.model.data;
  }

  get categoryId() {
    return this.args.model.categoryId || this.data?.category_id;
  }

  get modalTitle() {
    return i18n("js.discourse_reach_and_rights.table_title", {
      category_name: this.data?.category_name || "",
    });
  }

  <template>
    <DModal
      @title={{this.modalTitle}}
      @closeModal={{@closeModal}}
      class="reach-and-rights-details-modal"
    >
      <:body>
        <div data-category-id={{this.categoryId}}>
          <ReachAndRightsTable
            @data={{this.data}}
            @categoryId={{this.categoryId}}
            @showHeader="false"
          />
        </div>

        {{#if this.siteSettings.discourse_reach_and_rights_debug_enabled}}
          <div class="reach-and-rights-debug-info">
            <hr />
            <h4>{{i18n "js.discourse_reach_and_rights.debug_info_title"}}</h4>
            <pre>{{this.debugData}}</pre>
          </div>
        {{/if}}
      </:body>
    </DModal>
  </template>

  get debugData() {
    return JSON.stringify(this.data, null, 2);
  }
}
