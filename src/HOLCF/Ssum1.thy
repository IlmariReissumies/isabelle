(*  Title:      HOLCF/Ssum1.thy
    ID:         $Id$
    Author:     Franz Regensburger
    License:    GPL (GNU GENERAL PUBLIC LICENSE)

Partial ordering for the strict sum ++
*)

Ssum1 = Ssum0 +

instance "++"::(pcpo,pcpo)sq_ord

defs
  less_ssum_def "(op <<) == (%s1 s2.@z.
         (! u x. s1=Isinl u & s2=Isinl x --> z = u << x)
        &(! v y. s1=Isinr v & s2=Isinr y --> z = v << y)
        &(! u y. s1=Isinl u & s2=Isinr y --> z = (u = UU))
        &(! v x. s1=Isinr v & s2=Isinl x --> z = (v = UU)))"

end


