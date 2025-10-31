import {html, render} from "./modules/lit-html/lit-html.js";

/**
 * Simple table - takes a data attribute that is an array of arrays
 */
export class G3ReportsTable extends HTMLElement {
  constructor() {
    super();
    this._data = [];
  }

  connectedCallback() {
    this._render();
  }

  _render() {
      render( html`
        <table>
        <tbody>
        ${
          this._data.length > 0 ?
            this._data.map(
              row => html`<tr>${
                row.map(td => html`<td>${td}</td>`)
              }</tr>`
            )
            : html`<tr><td>No Data</td></tr>`
        }
        </tbody>
        </table>
      `, this);
  }

  set data(value) {
    this._data = value;
    this._render();
  }

  get data() { return this._data; }
}

window.customElements.define( "g3r-table", G3ReportsTable );
