
export class G3ReportsTable extends HTMLElement {
  constructor() {
    super();
    this._data = [];
  }

  connectedCallback() {
    this._render();
  }

  _render() {
    if (this._data.length > 0) {
      this.innerHTML = `
        <table>
        <tbody>
        ${
          this._data.map(
            row => `<tr>${
              row.map(td => `<td>${td}</td>`).join("")
            }</tr>`
          ).join("\n")
        }
        </tbody>
        </table>
      `;
    } else {
      this.innerHTML = `<table><tbody><tr><td>No Data</td></tr></tbody></table>`;
    }
  }

  set data(value) {
    this._data = value;
    this._render();
  }

  get data() { return this._data; }
}

window.customElements.define( "g3-reports-table", G3ReportsTable );
