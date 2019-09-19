
// shared functions

/**
 * Assemble the paths to fetch to get the data for the last 5 days
 * 
 * @param prefix
 * @return [pathDateList]
 */
function basicBuildPathList(prefix) {
  return [5,4,3,2,1].map(
    function(it) {
      const dt = new Date(Date.now() - it*24*60*60*1000);
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
 * max row gets 10 stars and ever other row is relative to that.
 * 
 * @param table to change in place
 * @return table
 */
function addStarColumn(table) {
  const max = table.reduce(
    (acc,row) => {
      if (typeof row[1] === 'number' && row[1] > acc) {
        return row[1];
      }
      return acc;
    }, 0
  );
  const stars='***************';
  table.forEach(
    (row) => {
      if (max > 0) {
        row.push(stars.substring(0, Math.floor(10*row[1]/max)));
      } else {
        row.push('');
      }
    }
  );
  return table;
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
          data
        };
      }
    );
  }
 
  massageData(fetchedData) {
    return {
      reportType: "users",
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
  constructor() {
  }

  buildPathDateList() {
    return basicBuildPathList("codes");
  }

  fetchData(pathDateList) {
    return fetchBucketsSummary(pathDateList, "codes"
      ).then(
        (data) => {
          return {
            reportType: "rcodes",
            data
          };
        }
      );
  }

  massageData(fetchedData) {
    return {
      reportType: "rcodes",
      massage: Object.entries(fetchedData.data).sort((a,b) => numCompare(a[0],b[0]))
    };
  }
}

/**
 * Handler for result times report
 */
export class RTimesHandler {
  constructor() {
  }

  buildPathDateList() {
    return basicBuildPathList("rtimes");
  }
 
  fetchData(pathDateList) {
    return fetchBucketsSummary(pathDateList, "rtimes"
      ).then(
        (data) => {
          return {
            reportType: "rtimes",
            data
          };
        }
      );
  }

  massageData(fetchedData) {
    return {
      reportType: "rtimes",
      massage: Object.entries(fetchedData.data).sort((a,b) => numCompare(a[0],b[0]))
    };
  }
}

//----------------------------

/**
 * Generate mock data for testing UX without backend
 */
function fetchRecentDataMock() {
  const result = {
    users: {
      reportType: "users",
      data: [

      ]
    },
    rcodes: {
      reportType: "rcodes",
      data: [

      ]
    },
    rtimes: {
      reportType: "rtimes",
      data: [

      ]
    }
  };

  Object.keys(result).map(
    (k) => {
      let bar='*';
      for(let i=0; i < 5; ++i) {
        result[k].data.push(
          [ k, "" + i, bar ] 
        );
        bar += '*';
      }
    }
  );
  return Promise.resolve(result);
}


const reportHandlers = {
  rtimes: new RTimesHandler(),
  rcodes: new RCodesHandler(),
  users: new UniqueUsersHandler()
};



export function fetchRecentData(reportType) {
  const handler = reportHandlers[reportType];
  return handler.fetchData(handler.buildPathDateList()
    ).then(
      (data) => {
        const result = handler.massageData(data);
        result.data = data.data;
        addStarColumn(result.massage);
        return result;
      }
    );
}

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


/**
 * Try to retrieve data for the last 5 days
 */
function fetchRecentDataFromNetwork() {
  const pathDateData = buildPathDateList();
  const rawData = { users: [], rtimes: [], rcodes: [] };
  fetchUserData(pathDateData.users
  ).then(
    function(userInfoList) {
      rawData.users = userInfoList;
      return fetchBucketsSummary(pathDateData.rcodes, );
    }
  ).then(
    function(rcodesSummary) {
      rawData.rcodes = rcodesSummary;
    }
  )
}



