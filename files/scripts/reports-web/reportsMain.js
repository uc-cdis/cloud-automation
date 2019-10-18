import './reportsTable.js';
import './reportsTabPanel.js';
import { amap, fetchRecentData } from './dataHelper.js';

const reportList = ['all', 'fence', 'guppy', 'indexd', 'peregrine', 'sheepdog'];

export function main() {
  const statusDOM = document.getElementById('status');
  const dataTables = {
    projects: { 'all': document.body.querySelector('.g3reports-projects g3r-table') },
    rcodes: reportList.reduce(
      (acc,name) => { acc[name] = document.body.querySelector(`.g3reports-rcodes div[name="${name}"] g3r-table`); return acc; }, 
      {}
    ),
    rtimes: reportList.reduce(
      (acc,name) => { acc[name] = document.body.querySelector(`.g3reports-rtimes div[name="${name}"] g3r-table`); return acc; }, 
      {}
    ),
    users: { 'all': document.body.querySelector('.g3reports-users g3r-table') },
  };

  statusDOM.innerHTML = `<p>Initializing</p>`;
  
  amap(
    Object.keys(dataTables), 
    (rtype) => fetchRecentData(rtype)
  ).then(
    (reportList) => {
      reportList.map(
        (info) => {
          dataTables[info.reportType].all.data = info.massage;
        }
      );
      statusDOM.innerHTML = `<p>Data downloaded</p>`;
    }
  );
}


main();