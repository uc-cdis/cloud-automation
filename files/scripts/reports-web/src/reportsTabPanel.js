/**
 * Simple tab - when clicked sets itself visible,
 * and sibling tabs to invisible
 */
export class G3ReportsTabPanel extends HTMLElement {
  constructor() {
    super();
    this._rendered = false;
  }

  connectedCallback() {
    this._render();
  }

  _render() {
    if (this._rendered) {
      return;
    }
    this._rendered = true;
    // render tabpanel controllers
    const nameList = Array.from(this.querySelectorAll('.g3r-tabpanel__tab')).map(el => el.getAttribute('name'));
    const controllers = `
      <ul class="g3r-tabpanel__buttonlist">
        ${nameList.map(name => `<li name="${name}" class="g3r-tabpanel__button">${name}</li>`).join("\n")}
      </ul>
    `;
    const controllerDiv = document.createElement('DIV');
    controllerDiv.innerHTML = controllers;
    if (this.children.length > 0) {
      this.insertBefore(controllerDiv, this.children[0]);
    } else {
      this.appendChild(controllerDiv);
    }
    controllerDiv.addEventListener('click', (ev) => {
      if (ev.target.nodeName === 'LI' && ev.target.getAttribute('name')) {
        this.toggle(ev.target.getAttribute('name'));
      }
    });
    if (nameList.length > 0) {
      // toggle the first tab
      this.toggle(nameList[0]);
    }
  }

  /**
   * Toggle the selected tab
   * 
   * @param {string} name of the selected tab
   */
  toggle(name) {
    Array.from(this.querySelectorAll('.g3r-tabpanel__tab')).forEach(
      (tab) => { 
        tab.classList.remove('g3r-tabpanel__tab_selected');
        if (tab.getAttribute('name') === name) {
          tab.classList.add('g3r-tabpanel__tab_selected');  
        }
      }
    );
    Array.from(this.querySelectorAll('.g3r-tabpanel__button')).forEach(
      (tab) => { 
        tab.classList.remove('g3r-tabpanel__button_selected');
        if (tab.getAttribute('name') === name) {
          tab.classList.add('g3r-tabpanel__button_selected');  
        }
      }
    );
  }
}

window.customElements.define("g3r-tabpanel", G3ReportsTabPanel);
