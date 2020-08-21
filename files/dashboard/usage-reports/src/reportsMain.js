import { amap, fetchRecentData, range, simpleDateFormat } from './dataHelper.js';
import './datePicker.js';
import './reportsTable.js';
import './reportsTabPanel.js';

const reportList = ['all', 'fence', 'guppy', 'indexd', 'peregrine', 'sheepdog'];

export function main() {
  let endDate = new Date();
  const dateDOM = document.querySelector('g3r-date-picker');
  const button = document.querySelector('button#button-go');
  button.addEventListener('click', (ev) => {
    const dt = dateDOM.date;
    const href = document.location.href.replace(/\?.+$/, `?end=${simpleDateFormat(dt)}`);
    document.location = href;
  });

  const queryParam = document.location.search.substring(1).split('&').reduce(
    (acc,it) => {
      const split = it.split('=');
      if (split.length === 2) {
        acc[split[0]] = split[1];
      }
      return acc;
    }, {}
  );
  if (queryParam['end']) {
    endDate = new Date(queryParam['end']);
    dateDOM.date = endDate;
  }
  const dateRange = range(1, 11).map(it => new Date(endDate - it*24*60*60*1000));
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
    (rtype) => fetchRecentData(rtype, 'all', dateRange)
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
    ({reportType, serviceName}) => fetchRecentData(reportType, serviceName, dateRange)
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