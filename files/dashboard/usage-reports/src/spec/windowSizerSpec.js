import '../windowSizer.js';


describe('the g3r-window-sizer custom element', function() {
  it('can render a window sizer', function(done) {
    const windowSizer = document.createElement('g3r-window-sizer');
    windowSizer.classList.add('window-sizer-spec');
    document.body.appendChild(windowSizer);
    setTimeout(() => {
      expect(document.querySelector('g3r-window-sizer.window-sizer-spec')).toBe(windowSizer);
      const it = windowSizer.querySelector('input')
      expect(it).toBeDefined();
      expect(windowSizer.windowSize).toBeGreaterThan(0);
      expect(windowSizer.windowSize).toBeLessThan(33);
      done();
    }, 50);
  });
});
