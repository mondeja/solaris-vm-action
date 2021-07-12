### Zip

```bash
zip sol-11_4.zip sol-11_4.ova
split --bytes=48MB sol-11_4.zip sol-11_4-part -d --additional-suffix=.zip
```

### Unzip

```bash
cat sol-11_4-part* > sol-11_4.zip
unzip sol-11_4.zip
```
