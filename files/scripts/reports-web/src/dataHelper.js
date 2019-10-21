
// shared functions

export function amap(list, lambda, result=[]) {
  if (list.length > 0) {
    return lambda(list[0]).then(
      (it) => {
        result.push(it);
        return amap(list.slice(1), lambda, result);
      }
    )
  } else {
    return Promise.resolve(result);
  }
}

export function range(start, end, step=1) {
  const result = [];
  if (end > start && step > 0 || end < start && step < 0) {
    for (let i=start; i < end; i += step) {
      result.push(i);
    }
  }
  return result;
}

/**
 * Assemble the paths to fetch to get the data for the last 5 days
 * Checks sessionStorage.gen3Now to trigger sample data date range - see ../README.md
 * 
 * @param prefix
 * @return [pathDateList]
 */
function basicBuildPathList(prefix, num=5) {
  const now = +(sessionStorage.getItem('gen3Now') || Date.now());
  return range(1, num+1).map(
    function(it) {
      const dt = new Date(now - it*24*60*60*1000);
      const part1 = `${dt.getUTCFullYear()}/${pad2(dt.getUTCMonth()+1)}/`;
      const part3 = `-${dt.getUTCFullYear()}${pad2(dt.getUTCMonth()+1)}${pad2(dt.getUTCDate())}.json`
      return { path:`${part1}${prefix}${part3}`, date: dt};
    }
  );
}

/**
 * Pad the given number with leading 0's to get a length of at least 2
 * @param {number} num
 * @return str possibly with leading 0 
 */
function pad2(num) {
  const str = "" + num;
  if (str.length > 1) {
    return str;
  }
  return ('00' + str).slice(-2);
}

/**
 * Given a table (list of rows) where column 2 holds the value,
 * append a list of up to 10 'stars' to each row where the
 * total row gets 10 stars and ever other row is relative to that.
 * 
 * @param table to change in place
 * @return table
 */
function addPercentColumn(table) {
  const total = table.reduce(
    (acc,row) => {
      if (typeof row[1] === 'number') {
        return row[1] + acc;
      }
      return acc;
    }, 0
  );
  table.forEach(
    (row) => {
      if (total > 0) {
        row.push(`${Math.floor(1000*row[1]/total)/10}%`);
      } else {
        row.push('');
      }
    }
  );
  return table;
}

/**
 * Given a range mapping {label, min, max}, and a table (list of rows)
 * where column 0 is in the range, and column1 is the accumulator,
 * then squish the histogram according to the mapping
 * 
 * @param table of source data
 * @param rangeMapping non-overlapping sorted [{label, min, max}]
 * @return squashTable with column 0 equal to label, and column 1 the sum 
 *        of all table rows that fall in the range
 */
function squash(table, rangeMapping) {
  const result = rangeMapping.map(info => [info.label, 0]);
  table.reduce((acc, row) => {
    let index=0;
    for (; index < rangeMapping.length-1 && rangeMapping[index].max <= row[0]; index++) {}
    acc[index][1] += row[1];
    return acc;
  }, result);
  return result;
}

/**
 * Fetch the result-codes data for each (date,path) pair,
 * and return the combined (key, count) summary for the given bucket aggregation
 *  
 * @param [{path,date}] pathDateList 
 * @param {string} aggName name of the aggregation
 * @return {number: rcode} mapping of "response code" to "number of responses"
 */
function fetchBucketsSummary(pathDateList, aggName) {
  return Promise.all(
    //
    // Fetch unique users data
    // Wind up with [ {date, count} ] list
    //
    pathDateList.map(
      ({path}) => fetch(path).then(
        response => response.json()
      ).then(
        data => data.aggregations[aggName].buckets.reduce(
          (acc, bucket) => {
            // round numbers to nearest .1
            const key = typeof bucket.key === 'number' ? Math.floor(bucket.key*10)/10 : bucket.key;
            acc[key] = bucket.doc_count;
            return acc;
          }, {}
        )
      ).catch( () => { return {} } 
      )
    )
  ).then(
    bucketMapList => 
      bucketMapList.reduce(
        (acc, bucketMap) => {
          Object.keys(bucketMap).forEach(
            (bucket) => {
              acc[bucket] = bucketMap[bucket] + (acc[bucket] || 0);
            }
          );
          return acc;
        }, {}
      )
  );
}

/**
 * numeric compare suitable for array sort()
 */
function numCompare(aIn,bIn) {
  const a = +aIn;
  const b = +bIn;
  return a < b ? -1 : a === b ? 0 : 1;
}

//--------------------------------------
// report handlers

/*
Handler interface {

   *
   * Build the list of paths and dates to fetch for data for the last 5 days
   * 
   buildPathDateList()

   *
   * Helper to massage fetchData result into list of lists 
   * suitable to render to table
   * 
   * @param {*} fetchedData 
   *
  massageData(fetchedData) {

   *
   * Fetch the data for each (date, path) pair
   * 
   * @param [{path,date}] pathDateList 
   * @return [ {number, date}] list of ("number of users", date) pairs
   *
   fetchData(pathDateList) {}

} 
 */

/**
 * Handler for unique users reports.
 */
class UniqueUsersHandler {
  constructor() {
  }

  buildPathDateList() {
    return basicBuildPathList("users");
  }

  fetchData(pathDateList) {
    return Promise.all(
      //
      // Fetch unique users data
      // Wind up with [ {date, count} ] list
      //
      pathDateList.map(
        ({path, date}) => fetch(path).then(
          response => response.json()
        ).then(
          data => data.aggregations["unique_user_count"].value
        ).catch( () => 0 
        ).then(
          number => { return {number, date}; }
        )
      )
    ).then(
      (data) => {
        return {
          reportType: "users",
          service: "all",
          data
        };
      }
    );
  }
 
  massageData(fetchedData) {
    return {
      ... fetchedData,
      massage: fetchedData.data.map( 
        ({number,date}) => [ `${date.getUTCFullYear()}/${pad2(date.getUTCMonth()+1)}/${pad2(date.getUTCDate())}`, "" + number ] 
        )
    };
  }
}


/**
 * Handler for result codes report
 */
export class RCodesHandler {
  constructor(service) {
    this.service = service || "all";
  }

  buildPathDateList() {
    let prefix = `codes-${this.service}`;
    if (this.service === 'all') {
      prefix = 'codes';
    }
    return basicBuildPathList(prefix);
  }

  fetchData(pathDateList) {
    return fetchBucketsSummary(pathDateList, "codes"
      ).then(
        (data) => {
          return {
            reportType: "rcodes",
            service: this.service,
            data
          };
        }
      );
  }

  massageData(fetchedData) {
    return {
      ... fetchedData,
      massage: addPercentColumn(
        Object.entries(fetchedData.data).sort((a,b) => numCompare(a[0],b[0]))
      )
    };
  }
}

/**
 * Handler for result times report
 */
export class RTimesHandler {
  constructor(service) {
    this.service = service || "all";
  }

  buildPathDateList() {
    let prefix = `rtimes-${this.service}`;
    if (this.service === 'all') {
      prefix = 'rtimes';
    }
    return basicBuildPathList(prefix);
  }
 
  fetchData(pathDateList) {
    return fetchBucketsSummary(pathDateList, "rtimes"
      ).then(
        (data) => {
          return {
            reportType: "rtimes",
            service: this.service,
            data
          };
        }
      );
  }

  massageData(fetchedData) {
    return {
      ... fetchedData,
      massage: addPercentColumn(
        //Object.entries(fetchedData.data).sort((a,b) => numCompare(a[0],b[0])),
        squash(
          Object.entries(fetchedData.data).sort((a,b) => numCompare(a[0],b[0])),
          [ 
            {label: '0-1 sec', min: 0, max: 1 },
            {label: '1-5 sec', min: 1, max: 5 },
            {label: '5-10 sec', min: 5, max: 10 },
            {label: '10+ sec', min: 10, max: 100 },
          ],
        )
      )
    };
  }
}

/**
 * Handler for dated data that is already in array-of-arrays
 * format suitable to pass directly through to reports.
 */
export class PassThroughHandler {
  constructor(key) {
    this.key = key;
  }

  buildPathDateList() {
    return basicBuildPathList(this.key, 1);
  }
 
  fetchData(pathDateList) {
    return fetch(pathDateList[0].path
      ).then(
        raw => raw.json()
      ).then(
        (data) => {
          return {
            reportType: this.key,
            service: 'all',
            data: data.data
          };
        }
      ).catch(
        (err) => {
          console.log(`failed fetch for ${this.key}`, err);
          return {
            reportType: this.key,
            service: 'all',
            data: []
          };
        }
      );
  }

  massageData(fetchedData) {
    return {
      ... fetchedData,
      massage: fetchedData.data
    };
  }
}

//----------------------------

const reportGroups = ['all', 'fence', 'indexd', 'guppy', 'peregrine', 'sheepdog'];
const reportHandlers = {
  rtimes: reportGroups.reduce((acc,it) => { acc[it] = new RTimesHandler(it); return acc; }, {}),
  rcodes: reportGroups.reduce((acc,it) => { acc[it] = new RCodesHandler(it); return acc; }, {}),
  users: {
    all: new UniqueUsersHandler()
  },
  projects: {
    all: new PassThroughHandler('projects')
  }
};


export function fetchRecentData(reportType, reportGroup='all') {
  if (! (reportHandlers[reportType] && reportHandlers[reportType][reportGroup])) {
    const message = `ERROR: invalid report ${reportType}/${reportGroup}`;
    console.log(message);
    return [[message]];
  }
  const handler = reportHandlers[reportType][reportGroup];
  return handler.fetchData(handler.buildPathDateList()
    ).then(
      (data) => {
        const result = handler.massageData(data);
        result.data = data.data;
        return result;
      }
    );
}

