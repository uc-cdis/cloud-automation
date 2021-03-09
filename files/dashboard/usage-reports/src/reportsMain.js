import { amap, fetchRecentData } from './dataHelper.js';
import './datePicker.js';
import './reportsTable.js';
import './reportsTabPanel.js';
import './windowSizer.js';

const reportList = ['all', 'fence', 'guppy', 'indexd', 'peregrine', 'sheepdog'];

export function main() {
  const windowDOM = document.querySelector('g3r-window-sizer');
  const dateRange = windowDOM.dateRange;
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
    protocol: { 'all': document.body.querySelector('.g3reports-downloadprotocol g3r-table') },
    loginproviders: { 'all': document.body.querySelector('.g3reports-loginproviders g3r-table') },
    ga4ghrcodes: { 'all': document.body.querySelector('.g3reports-drsrcodes g3r-table') },
  };

  statusDOM.innerHTML = `<p>Initializing</p>`;
  
  // Download data in the 'all' tabs
  amap(
    Object.keys(dataTables), 
    (rtype) => fetchRecentData(rtype, 'all', dateRange)
  ).then(
    (infoList) => {
      infoList.map(
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
    ({reportType, serviceName}) => fetchRecentData(reportType, serviceName, dateRange)
  ).then(
    (infoList) => {
      infoList.map(
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
