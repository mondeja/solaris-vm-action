### Zip

```bash
zip sol-11_4.zip sol-11_4.ova
split --bytes=49MB sol-11_4.zip sol-11_4-part -d --additional-suffix=.zip
```

### Unzip

```bash
cat sol-11_4-part* > sol-11_4.zip
unzip sol-11_4.zip
```

### Forced tag update

```bash
git reset --soft <hash> && git add . && git commit -m "Try another ova" && git push -f origin master && git push -d origin v1 && git tag -d v1; git tag -a v1 -m "First releease" && git push origin v1
```
