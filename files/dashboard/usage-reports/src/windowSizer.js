import { range, simpleDateFormat } from './dataHelper.js';
import { html, render } from "./modules/lit-html/lit-html.js";

/**
 * Simple table - takes a data attribute that is an array of arrays
 */
export class G3WindowSizer extends HTMLElement {
  constructor() {
    super();
    this._date = new Date();
    this._listener = null;
  }

  connectedCallback() {
    this._render();
  }

  _render() {
    // see https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input/datetime-local
    render( html`
      <div class="g3-window-sizer__input">
         <label for="windowsize">Window size in days</label>
         <input id="windowsize" type="text" value="${this.windowSize}" />
      </div>
      <div class="g3-window-sizer__input">
      <g3r-date-picker date="${simpleDateFormat(this.endDate)}"></g3-date-picker>
      </div>
      <div class="g3-window-sizer__input">
        <button class="button_action" id="button-go" type="button">Go</button>
      </div>
    `, this);

    if (!this._listener) {
      // first render
      this._listener = (ev) => {
          const dt = this.querySelector('g3r-date-picker').date;
          const windowSize = +this.querySelector('input#windowsize').value || 10;
          const href = document.location.href.replace(/\?.+$/, '') + `?end=${simpleDateFormat(dt)}&size=${windowSize}`;
          document.location = href;
      };
      const button = this.querySelector('button');
      button.addEventListener('click', this._listener);
    }

  }

  _endDate = null;
  _windowSize = 0;
  _dateRange = null;

  
  get endDate() {
    this._init();
    return this._endDate;
  }

  get dateRange() {
    this._init();
    return this._dateRange;
  }

  get windowSize() {
    this._init();
    return this._windowSize;
  }

  _init() {
    if (this._dateRange) {
      return;
    }
  
    const queryParam = document.location.search.substring(1).split('&').reduce(
      (acc,it) => {
        const split = it.split('=');
        if (split.length === 2) {
          acc[split[0]] = split[1];
        }
        return acc;
      }, {}
    );
    let endDate = new Date();
    let windowSize = 10;

    if (queryParam['end']) {
      endDate = new Date(queryParam['end']);
    }
    if (queryParam['size']) {
      windowSize = +queryParam['size'];
      if (windowSize > 32) {
        windowSize = 32;
      }
      if (windowSize < 3) {
        windowSize = 3;
      }
    }
    this._endDate = endDate;
    this._windowSize = windowSize;
    this._dateRange = range(1, windowSize + 1).map(it => new Date(endDate - it*24*60*60*1000));
    return this._dateRange;
  }
}

window.customElements.define('g3r-window-sizer', G3WindowSizer);
