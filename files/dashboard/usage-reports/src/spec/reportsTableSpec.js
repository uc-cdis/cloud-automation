import '../reportsTable.js';


describe('the g3r-table custom element', function() {
  it('can render a table', function(done) {
    const table = document.createElement('g3r-table');
    const testData = [
      [ "cell 0,0", "cell 1,0", "cell 2,0" ],
      [ "cell 0,1", "cell 1,1", "cell 2,1" ],
    ];
    table.data = testData;
    table.classList.add("reports-table-spec");
    document.body.appendChild(table);
    setTimeout(() => {
      expect(document.querySelector("g3r-table.reports-table-spec")).toBe(table);
      expect(table.querySelectorAll('tr').length).toBe(2);
      expect(table.querySelectorAll('td').length).toBe(6);
      done();
    }, 50);
  });
});
