import { html, render } from "./modules/lit-html/lit-html.js";
import { simpleDateFormat } from './dataHelper.js';

/**
 * Simple table - takes a data attribute that is an array of arrays
 */
export class G3DatePicker extends HTMLElement {
  constructor() {
    super();
    this._date = null;
    this._id = `dt${Math.floor(Math.random()*1000)}${Date.now()}`;
  }

  connectedCallback() {
    this._render();
  }

  _init() {
    if (!this._date) {
      if (this.getAttribute("date")) {
        this._date = new Date(this.getAttribute("date"));
      } else {
        this._date = new Date();
      }
    }
  }

  _render() {
    this._init();
    // see https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input/datetime-local
    render( html`
      <label for="${this._id}">End date of report window</label>
      <input id="${this._id}" type="datetime-local" name="whatever" value="${ simpleDateFormat(this._date, '-') + "T00:00" }" />
    `, this);
  }

  set date(value) {
    this._date = value;
    this._render();
  }

  get date() {
    this._init();
    const inputDOM = this.querySelector('input');
    if (inputDOM) {
      this._date = new Date(inputDOM.value);
    }
    return this._date;
  }
}

window.customElements.define( "g3r-date-picker", G3DatePicker );
