The test for replace functions is design for following 6 cases:

### simple key-value:
*origin yaml:*

```
# some comments for pub
pub: '_________'
```

*input yaml:*

```
pub: 'some pub config'
```

*result yaml:*

```
# some comments for pub
pub: 'some pub config'
```


### (nested) properties:
*origin yaml:*

```
# some comments for pub_level_0
pub_level_0:
  # some comments for pub_level_1
  pub_level_1:
    # some comments for pub_level_2
    pub_level_2: '__________'
```

*input yaml:*

```
pub_level_0:
  pub_level_1:
    pub_level_2: 'some pub config'
```

*result yaml:*

```
# some comments for pub_level_0
pub_level_0:
  # some comments for pub_level_1
  pub_level_1:
    # some comments for pub_level_2
    pub_level_2: 'some pub config'
```


### commented object:
*origin yaml:*

```
# some comments
# pub2_level_0:
#   pub2_level_1:
#     sec_level_2: '________'
#   sec_level_1: '________'
```

*input yaml:*

```
pub2_level_0:
  pub2_level_1:
    sec_level_2: 'example'
    sec_level_1: 'example'
```

*result yaml:*

```
# some comments
pub2_level_0:
  pub2_level_1:
    sec_level_2: 'example'
  sec_level_1: 'example'
```


### list:
*origin yaml:*

```
pub3_level_0:
  - 'pub_item_1'
  - 'pub_item_2'
```

*input yaml:*

```
pub3_level_0:
  - 'pub_item_3'
  - 'pub_item_4'
```

*result yaml: (replace the whole list)*

```
pub3_level_0:
  - 'pub_item_3'
  - 'pub_item_4'
```

### replace an empty list:
*origin yaml:*

```
pub3_level_0: []
#  - 'pub_item_1'
#  - 'pub_item_2'
```

*input yaml:*

```
pub3_level_0:
  - 'pub_item_1'
  - 'pub_item_2'
```

*result yaml:*

```
pub3_level_0:
  - 'pub_item_1'
  - 'pub_item_2'
#  - 'pub_item_1'
#  - 'pub_item_2'
```

### replace with empty list: TODO
*origin yaml:*

```
pub3_level_0:
  - 'pub_item_1'
  - 'pub_item_2'
```

*input yaml:*

```
pub3_level_0: []
```

*result yaml:*

```
pub3_level_0:
```