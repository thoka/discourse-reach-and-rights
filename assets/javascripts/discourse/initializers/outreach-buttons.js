import { iconHTML } from "discourse/lib/icon-library";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "outreach-buttons",
  // ToDo: wir brauchen dies wahrscheinlich nicht
  initialize() {
    withPluginApi("1.34.0", (api) => {
      // Wir nutzen onPageChange, um alle relevanten Buttons im DOM zu finden.
      // Dies erfasst sowohl GJS-Komponenten als auch Widgets.
      api.onPageChange(() => {
        return;
        console.log("Outreach-Button-Initializer läuft");
        const buttons = document.querySelectorAll(
          "#create-topic, .btn-primary.create, .btn-primary.reply"
        );

        buttons.forEach((btn) => {
          // Verhindere mehrfaches Hinzufügen
          console.log("--btn", btn);
          if (btn.querySelector(".outreach-info")) {
            return;
          }

          // In der Kategorie-Ansicht holen wir uns die Daten aus dem Speicher/Controller
          // Für diesen ersten Schritt nutzen wir Demo-Daten (✉️ 12 👁️ 34)
          const outreach = 12;
          const watching = 34;

          const container = document.createElement("span");
          container.classList.add("outreach-info");
          container.innerHTML = `
            ${iconHTML("envelope")}<span class="outreach-send">${outreach}</span> 
            ${iconHTML("eye")}<span class="outreach-view">${watching}</span>
          `;

          btn.appendChild(container);
        });
      });
    });
  },
};