
# https://gist.github.com/yurenchen000/5f52d0b7c1a0104d1a4fb6f3bf119b35

find_pkg(){
  local name=$1
  local f
  awk '$1 ~ /^src/' /opt/etc/opkg.conf | while read type repo url pad; do
    f=/opt/var/opkg-lists/$repo
	{
      [ $type == "src/gz" ] && zcat $f || cat $f;
    } | {
      awk -vname="$name" '$1=="Package:" && $2==name {f=1;r=1} $0=="" {f=0} f {print} END{exit 1-r}'
    } | while read key val pad; do
      [ "$key" == "Version:" ] && ver=$val
      [ "$key" == "Filename:" ] && {
        echo found $ver @$repo
        echo $url/$val
      }
    done
  done
}
