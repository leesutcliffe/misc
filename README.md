# Quick and dirty shell script to find unused certificates

The following bash script will output any installed certificate names to a file, then iterate over each line. If the certificate is not referenced in bigip.conf in either the /config/ or within a partition folder, then it can be reasonably assumed it is not in use and can be safely deleted.

The script will give you the option to delete any certs that are not in use and save a UCS archive (just in case) If there are any keys associated with the certificate, this will be deleted too.

As the moment, the script will not look for keys without an equivalent cert, e.g. my-cert.key and my-cert.crt. So you many still end up with rogue keys. I'll look to get this updated eventually.

There is an array called ignoreCerts

```
ignoreCerts=("f5-irule.crt" "ca-bundle.crt")
```

Here you can add certificates you may want to ignore. For example, f5-irule.crt is used to sign F5 provided iRules and bigip.conf does not reference it. Add any additional certs to this array to ensure they are not deleted
