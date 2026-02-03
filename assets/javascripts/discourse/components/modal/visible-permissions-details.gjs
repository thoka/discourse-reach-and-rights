import Component from "@glimmer/component";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";
import VisiblePermissionsTable from "../visible-permissions/table";

export default class VisiblePermissionsDetails extends Component {
  get data() {
    return this.args.model.data;
  }

  get categoryId() {
    return this.args.model.categoryId || this.data?.category_id;
  }

  get modalTitle() {
    return i18n("js.discourse_visible_permissions.table_title", {
      category_name: this.data?.category_name || "",
    });
  }

  <template>
    <DModal
      @title={{this.modalTitle}}
      @closeModal={{@closeModal}}
      class="visible-permissions-details-modal"
    >
      <:body>
        <div data-category-id={{this.categoryId}}>
          <VisiblePermissionsTable
            @data={{this.data}}
            @categoryId={{this.categoryId}}
            @showHeader=false
          />
        </div>
      </:body>
    </DModal>
  </template>
}
