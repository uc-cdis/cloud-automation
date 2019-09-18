import './reportsTable.js';
import { amap, fetchRecentData } from './dataHelper.js';

export function main() {
  const statusDOM = document.getElementById('status');
  const dataTables = {
    users: document.body.querySelector('.g3reports-users g3-reports-table'),
    rcodes: document.body.querySelector('.g3reports-rcodes g3-reports-table'),
    rtimes: document.body.querySelector('.g3reports-rtimes g3-reports-table'),
    projects: document.body.querySelector('.g3reports-projects g3-reports-table')
  };

  statusDOM.innerHTML = `<p>Initializing</p>`;
  amap(
    Object.keys(dataTables), 
    (rtype) => fetchRecentData(rtype)
  ).then(
    (reportList) => {
      reportList.map(
        (info) => {
          dataTables[info.reportType].data = info.massage;
        }
      );
      statusDOM.innerHTML = `<p>Data downloaded</p>`;
    }
  );
}


main();