import { simpleDateFormat } from '../dataHelper.js';
import '../datePicker.js';


describe('the g3r-date-picker custom element', function() {
  it('can render a date picker', function(done) {
    const datePicker = document.createElement('g3r-date-picker');
    datePicker.classList.add('date-picker-spec');
    document.body.appendChild(datePicker);
    setTimeout(() => {
      expect(document.querySelector('g3r-date-picker.date-picker-spec')).toBe(datePicker);
      const it = datePicker.querySelector('input')
      expect(it).toBeDefined();
      expect(it.value.startsWith(simpleDateFormat(new Date(), '-'))).toBe(true, `datePicker has valid value: ${it.value}`);
      const dt = new Date(it.value);
      expect(dt).toBeDefined(`able to construct date from ${it.value}`);
      done();
    }, 50);
  });
});
