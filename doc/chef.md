# TL;DR

Run chef roles defined in cloud-automation

## Use

### role

Run specific chef role

```bash
  gen3 chef role <role name>
```

### recipe

Run specific cookbook recipe

```bash
  gen3 chef recipe <recipe name>
```

### initialize

Used to initialize chef on adminvm. Other commands will also run this if chef has not been initialized previously so this can mostly be used to reinitialize an invalid chef setup.

```bash
   gen3 chef initialize
```
