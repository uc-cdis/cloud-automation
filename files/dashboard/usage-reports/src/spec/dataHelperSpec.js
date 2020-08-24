import {amap, basicBuildPathList, range, simpleDateFormat} from '../dataHelper.js';
              
describe('the dataHelper', function() {

  it('has a range helper', function() {
    const probe = range(1,5,1)
    expect(probe.length).toBe(4);
    expect(probe).toEqual([1,2,3,4]);
  });

  it('can build fetch paths given a number of days back from now', function() {
    const pathList = basicBuildPathList('test', 5);
    expect(pathList.length).toBe(5);
  });

  it('can build fetch paths given a date range', function() {
    const pathList = basicBuildPathList('test', ['2020/08/20', '2020/08/19', '2020/08/18']);
    expect(pathList.length).toBe(3);
  });

  it('can format a date', function() {
    const dateStr = simpleDateFormat(new Date());
    expect(/\d\d\d\d\/\d\d\/\d\d/.test(dateStr)).toBe(true, `got expected date format: ${dateStr}`);
  })

});
