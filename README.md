# Julia ansible provisioning scripts

These scripts are what I use to provision things like buildslaves, the cache server, etc... Invoke them with `ansible-playbook` in a manner such as the following:

```
$ ansible-playbook -i hosts -v buildslaves.yml -l buildslave_osx10.11-x64,buildslave_win6.1-x64
```

If IP addresses/ports change, update the relevant entries in `hosts`.  
