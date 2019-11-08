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
  
  // Download data in the 'all' tabs
  amap(
    Object.keys(dataTables), 
    (rtype) => fetchRecentData(rtype)
  ).then(
    (reportList) => {
      reportList.map(
        (info) => {
          dataTables[info.reportType][info.service].data = info.massage;
        }
      );
      statusDOM.innerHTML = `<p>Initial data downloaded ...</p>`;
    }
  );
  // Go ahead and fetch data in other tabs now
  amap(
    reportList.slice(1).reduce((acc, serviceName) => {
      ['rtimes', 'rcodes'].forEach((reportType) => { acc.push({serviceName, reportType}); });
      return acc;
    }, []),
    ({reportType, serviceName}) => fetchRecentData(reportType, serviceName)
  ).then(
    (reportList) => {
      reportList.map(
        (info) => {
          //console.log(`Rendering ${info.service} ${info.reportType}`, info);
          dataTables[info.reportType][info.service].data = info.massage;
        }
      );
      statusDOM.innerHTML = `<p>All data downloaded</p>`;
    }
  );
}


main();