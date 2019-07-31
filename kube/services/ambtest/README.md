# TL;DR

Little helper pod to help debug ambassador-gen3 deployment

## Overview

* Open http://ambassador-elb/test/index.html
* Can fetch request headers echo'ed in response:

```
fetch( '/test/frickjack', { credentials: 'same-origin', headers: { 'X-CSRF-Token': 'frickjack', Authorization: 'bla' }}).then( r => r.text() ).then( s => console.log('Got: ' + s) )
```
