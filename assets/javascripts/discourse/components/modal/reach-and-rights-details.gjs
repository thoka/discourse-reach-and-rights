import Component from "@glimmer/component";
import DModal from "discourse/components/d-modal";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import ReachAndRightsTable from "../reach-and-rights/table";

export default class ReachAndRightsDetails extends Component {
  get data() {
    return this.args.model.data;
  }

  get categoryId() {
    return this.args.model.categoryId || this.data?.category_id;
  }

  get category() {
    return this.args.model.category || Category.findById(this.categoryId);
  }

  get modalTitle() {
    const categoryName = this.data?.category_name || this.category?.name || "";
    return i18n("js.discourse_reach_and_rights.table_title", {
      category_name: categoryName,
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
            @category={{this.category}}
            @showHeader="false"
          />
        </div>
      </:body>
    </DModal>
  </template>
}
