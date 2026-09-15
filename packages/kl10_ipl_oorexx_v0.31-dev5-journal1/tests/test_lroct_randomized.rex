numeric digits 30
count = 0
call assertEq (Oct("000000,,000000") + Oct("000000,,000000"))~string, "000000,,000000", "add 0"
count = count + 1
call assertEq (Oct("000000,,000000") - Oct("000000,,000000"))~string, "000000,,000000", "sub 0"
count = count + 1
call assertEq (Oct("000000,,000000") & Oct("000000,,000000"))~string, "000000,,000000", "and 0"
count = count + 1
call assertEq (Oct("000000,,000000") | Oct("000000,,000000"))~string, "000000,,000000", "or 0"
count = count + 1
call assertEq (Oct("000000,,000000") && Oct("000000,,000000"))~string, "000000,,000000", "xor 0"
count = count + 1
call assertEq Oct("000000,,000000")~shl(13)~string, "000000,,000000", "shl 0"
count = count + 1
call assertEq Oct("000000,,000000")~shr(13)~string, "000000,,000000", "shr 0"
count = count + 1
call assertEq (Oct("777777,,777777") + Oct("000000,,000001"))~string, "000000,,000000", "add 1"
count = count + 1
call assertEq (Oct("777777,,777777") - Oct("000000,,000001"))~string, "777777,,777776", "sub 1"
count = count + 1
call assertEq (Oct("777777,,777777") & Oct("000000,,000001"))~string, "000000,,000001", "and 1"
count = count + 1
call assertEq (Oct("777777,,777777") | Oct("000000,,000001"))~string, "777777,,777777", "or 1"
count = count + 1
call assertEq (Oct("777777,,777777") && Oct("000000,,000001"))~string, "777777,,777776", "xor 1"
count = count + 1
call assertEq Oct("777777,,777777")~shl(33)~string, "700000,,000000", "shl 1"
count = count + 1
call assertEq Oct("777777,,777777")~shr(33)~string, "000000,,000007", "shr 1"
count = count + 1
call assertEq (Oct("000000,,777777") + Oct("000000,,000001"))~string, "000001,,000000", "add 2"
count = count + 1
call assertEq (Oct("000000,,777777") - Oct("000000,,000001"))~string, "000000,,777776", "sub 2"
count = count + 1
call assertEq (Oct("000000,,777777") & Oct("000000,,000001"))~string, "000000,,000001", "and 2"
count = count + 1
call assertEq (Oct("000000,,777777") | Oct("000000,,000001"))~string, "000000,,777777", "or 2"
count = count + 1
call assertEq (Oct("000000,,777777") && Oct("000000,,000001"))~string, "000000,,777776", "xor 2"
count = count + 1
call assertEq Oct("000000,,777777")~shl(6)~string, "000077,,777700", "shl 2"
count = count + 1
call assertEq Oct("000000,,777777")~shr(6)~string, "000000,,007777", "shr 2"
count = count + 1
call assertEq (Oct("000001,,000000") + Oct("000000,,000001"))~string, "000001,,000001", "add 3"
count = count + 1
call assertEq (Oct("000001,,000000") - Oct("000000,,000001"))~string, "000000,,777777", "sub 3"
count = count + 1
call assertEq (Oct("000001,,000000") & Oct("000000,,000001"))~string, "000000,,000000", "and 3"
count = count + 1
call assertEq (Oct("000001,,000000") | Oct("000000,,000001"))~string, "000001,,000001", "or 3"
count = count + 1
call assertEq (Oct("000001,,000000") && Oct("000000,,000001"))~string, "000001,,000001", "xor 3"
count = count + 1
call assertEq Oct("000001,,000000")~shl(33)~string, "000000,,000000", "shl 3"
count = count + 1
call assertEq Oct("000001,,000000")~shr(33)~string, "000000,,000000", "shr 3"
count = count + 1
call assertEq (Oct("400000,,000000") + Oct("400000,,000000"))~string, "000000,,000000", "add 4"
count = count + 1
call assertEq (Oct("400000,,000000") - Oct("400000,,000000"))~string, "000000,,000000", "sub 4"
count = count + 1
call assertEq (Oct("400000,,000000") & Oct("400000,,000000"))~string, "400000,,000000", "and 4"
count = count + 1
call assertEq (Oct("400000,,000000") | Oct("400000,,000000"))~string, "400000,,000000", "or 4"
count = count + 1
call assertEq (Oct("400000,,000000") && Oct("400000,,000000"))~string, "000000,,000000", "xor 4"
count = count + 1
call assertEq Oct("400000,,000000")~shl(13)~string, "000000,,000000", "shl 4"
count = count + 1
call assertEq Oct("400000,,000000")~shr(13)~string, "000020,,000000", "shr 4"
count = count + 1
call assertEq (Oct("000000,,000000") + Oct("000000,,000001"))~string, "000000,,000001", "add 5"
count = count + 1
call assertEq (Oct("000000,,000000") - Oct("000000,,000001"))~string, "777777,,777777", "sub 5"
count = count + 1
call assertEq (Oct("000000,,000000") & Oct("000000,,000001"))~string, "000000,,000000", "and 5"
count = count + 1
call assertEq (Oct("000000,,000000") | Oct("000000,,000001"))~string, "000000,,000001", "or 5"
count = count + 1
call assertEq (Oct("000000,,000000") && Oct("000000,,000001"))~string, "000000,,000001", "xor 5"
count = count + 1
call assertEq Oct("000000,,000000")~shl(0)~string, "000000,,000000", "shl 5"
count = count + 1
call assertEq Oct("000000,,000000")~shr(0)~string, "000000,,000000", "shr 5"
count = count + 1
call assertEq (Oct("000000,,000001") + Oct("000000,,000001"))~string, "000000,,000002", "add 6"
count = count + 1
call assertEq (Oct("000000,,000001") - Oct("000000,,000001"))~string, "000000,,000000", "sub 6"
count = count + 1
call assertEq (Oct("000000,,000001") & Oct("000000,,000001"))~string, "000000,,000001", "and 6"
count = count + 1
call assertEq (Oct("000000,,000001") | Oct("000000,,000001"))~string, "000000,,000001", "or 6"
count = count + 1
call assertEq (Oct("000000,,000001") && Oct("000000,,000001"))~string, "000000,,000000", "xor 6"
count = count + 1
call assertEq Oct("000000,,000001")~shl(13)~string, "000000,,020000", "shl 6"
count = count + 1
call assertEq Oct("000000,,000001")~shr(13)~string, "000000,,000000", "shr 6"
count = count + 1
call assertEq (Oct("123456,,765432") + Oct("000000,,600000"))~string, "123457,,565432", "add 7"
count = count + 1
call assertEq (Oct("123456,,765432") - Oct("000000,,600000"))~string, "123456,,165432", "sub 7"
count = count + 1
call assertEq (Oct("123456,,765432") & Oct("000000,,600000"))~string, "000000,,600000", "and 7"
count = count + 1
call assertEq (Oct("123456,,765432") | Oct("000000,,600000"))~string, "123456,,765432", "or 7"
count = count + 1
call assertEq (Oct("123456,,765432") && Oct("000000,,600000"))~string, "123456,,165432", "xor 7"
count = count + 1
call assertEq Oct("123456,,765432")~shl(2)~string, "516273,,726150", "shl 7"
count = count + 1
call assertEq Oct("123456,,765432")~shr(2)~string, "024713,,575306", "shr 7"
count = count + 1
call assertEq (Oct("640467,,230524") + Oct("074615,,630113"))~string, "735305,,060637", "add 8"
count = count + 1
call assertEq (Oct("640467,,230524") - Oct("074615,,630113"))~string, "543651,,400411", "sub 8"
count = count + 1
call assertEq (Oct("640467,,230524") & Oct("074615,,630113"))~string, "040405,,230100", "and 8"
count = count + 1
call assertEq (Oct("640467,,230524") | Oct("074615,,630113"))~string, "674677,,630537", "or 8"
count = count + 1
call assertEq (Oct("640467,,230524") && Oct("074615,,630113"))~string, "634272,,400437", "xor 8"
count = count + 1
call assertEq Oct("640467,,230524")~shl(7)~string, "115646,,125000", "shl 8"
count = count + 1
call assertEq Oct("640467,,230524")~shr(7)~string, "003202,,335142", "shr 8"
count = count + 1
call assertEq (Oct("557003,,663137") + Oct("257240,,716166"))~string, "036244,,601325", "add 9"
count = count + 1
call assertEq (Oct("557003,,663137") - Oct("257240,,716166"))~string, "277542,,744751", "sub 9"
count = count + 1
call assertEq (Oct("557003,,663137") & Oct("257240,,716166"))~string, "057000,,602126", "and 9"
count = count + 1
call assertEq (Oct("557003,,663137") | Oct("257240,,716166"))~string, "757243,,777177", "or 9"
count = count + 1
call assertEq (Oct("557003,,663137") && Oct("257240,,716166"))~string, "700243,,175051", "xor 9"
count = count + 1
call assertEq Oct("557003,,663137")~shl(5)~string, "740173,,145740", "shl 9"
count = count + 1
call assertEq Oct("557003,,663137")~shr(5)~string, "013360,,075462", "shr 9"
count = count + 1
call assertEq (Oct("373777,,444132") + Oct("246741,,763750"))~string, "642741,,430102", "add 10"
count = count + 1
call assertEq (Oct("373777,,444132") - Oct("246741,,763750"))~string, "125035,,460162", "sub 10"
count = count + 1
call assertEq (Oct("373777,,444132") & Oct("246741,,763750"))~string, "242741,,440110", "and 10"
count = count + 1
call assertEq (Oct("373777,,444132") | Oct("246741,,763750"))~string, "377777,,767772", "or 10"
count = count + 1
call assertEq (Oct("373777,,444132") && Oct("246741,,763750"))~string, "135036,,327662", "xor 10"
count = count + 1
call assertEq Oct("373777,,444132")~shl(37)~string, "000000,,000000", "shl 10"
count = count + 1
call assertEq Oct("373777,,444132")~shr(37)~string, "000000,,000000", "shr 10"
count = count + 1
call assertEq (Oct("246611,,240146") + Oct("746475,,000400"))~string, "215306,,240546", "add 11"
count = count + 1
call assertEq (Oct("246611,,240146") - Oct("746475,,000400"))~string, "300114,,237546", "sub 11"
count = count + 1
call assertEq (Oct("246611,,240146") & Oct("746475,,000400"))~string, "246411,,000000", "and 11"
count = count + 1
call assertEq (Oct("246611,,240146") | Oct("746475,,000400"))~string, "746675,,240546", "or 11"
count = count + 1
call assertEq (Oct("246611,,240146") && Oct("746475,,000400"))~string, "500264,,240546", "xor 11"
count = count + 1
call assertEq Oct("246611,,240146")~shl(18)~string, "240146,,000000", "shl 11"
count = count + 1
call assertEq Oct("246611,,240146")~shr(18)~string, "000000,,246611", "shr 11"
count = count + 1
call assertEq (Oct("124725,,072364") + Oct("302454,,557132"))~string, "427401,,651516", "add 12"
count = count + 1
call assertEq (Oct("124725,,072364") - Oct("302454,,557132"))~string, "622250,,313232", "sub 12"
count = count + 1
call assertEq (Oct("124725,,072364") & Oct("302454,,557132"))~string, "100404,,052120", "and 12"
count = count + 1
call assertEq (Oct("124725,,072364") | Oct("302454,,557132"))~string, "326775,,577376", "or 12"
count = count + 1
call assertEq (Oct("124725,,072364") && Oct("302454,,557132"))~string, "226371,,525256", "xor 12"
count = count + 1
call assertEq Oct("124725,,072364")~shl(20)~string, "351720,,000000", "shl 12"
count = count + 1
call assertEq Oct("124725,,072364")~shr(20)~string, "000000,,025165", "shr 12"
count = count + 1
call assertEq (Oct("014651,,432161") + Oct("077344,,271354"))~string, "114215,,723535", "add 13"
count = count + 1
call assertEq (Oct("014651,,432161") - Oct("077344,,271354"))~string, "715305,,140605", "sub 13"
count = count + 1
call assertEq (Oct("014651,,432161") & Oct("077344,,271354"))~string, "014240,,030140", "and 13"
count = count + 1
call assertEq (Oct("014651,,432161") | Oct("077344,,271354"))~string, "077755,,673375", "or 13"
count = count + 1
call assertEq (Oct("014651,,432161") && Oct("077344,,271354"))~string, "063515,,643235", "xor 13"
count = count + 1
call assertEq Oct("014651,,432161")~shl(34)~string, "200000,,000000", "shl 13"
count = count + 1
call assertEq Oct("014651,,432161")~shr(34)~string, "000000,,000000", "shr 13"
count = count + 1
call assertEq (Oct("671524,,001173") + Oct("123345,,504325"))~string, "015071,,505520", "add 14"
count = count + 1
call assertEq (Oct("671524,,001173") - Oct("123345,,504325"))~string, "546156,,274646", "sub 14"
count = count + 1
call assertEq (Oct("671524,,001173") & Oct("123345,,504325"))~string, "021104,,000121", "and 14"
count = count + 1
call assertEq (Oct("671524,,001173") | Oct("123345,,504325"))~string, "773765,,505377", "or 14"
count = count + 1
call assertEq (Oct("671524,,001173") && Oct("123345,,504325"))~string, "752661,,505256", "xor 14"
count = count + 1
call assertEq Oct("671524,,001173")~shl(15)~string, "400117,,300000", "shl 14"
count = count + 1
call assertEq Oct("671524,,001173")~shr(15)~string, "000006,,715240", "shr 14"
count = count + 1
call assertEq (Oct("772022,,725635") + Oct("225515,,671600"))~string, "217540,,617435", "add 15"
count = count + 1
call assertEq (Oct("772022,,725635") - Oct("225515,,671600"))~string, "544305,,034035", "sub 15"
count = count + 1
call assertEq (Oct("772022,,725635") & Oct("225515,,671600"))~string, "220000,,621600", "and 15"
count = count + 1
call assertEq (Oct("772022,,725635") | Oct("225515,,671600"))~string, "777537,,775635", "or 15"
count = count + 1
call assertEq (Oct("772022,,725635") && Oct("225515,,671600"))~string, "557537,,154035", "xor 15"
count = count + 1
call assertEq Oct("772022,,725635")~shl(32)~string, "640000,,000000", "shl 15"
count = count + 1
call assertEq Oct("772022,,725635")~shr(32)~string, "000000,,000017", "shr 15"
count = count + 1
call assertEq (Oct("670027,,524335") + Oct("105063,,200572"))~string, "775112,,725127", "add 16"
count = count + 1
call assertEq (Oct("670027,,524335") - Oct("105063,,200572"))~string, "562744,,323543", "sub 16"
count = count + 1
call assertEq (Oct("670027,,524335") & Oct("105063,,200572"))~string, "000023,,000130", "and 16"
count = count + 1
call assertEq (Oct("670027,,524335") | Oct("105063,,200572"))~string, "775067,,724777", "or 16"
count = count + 1
call assertEq (Oct("670027,,524335") && Oct("105063,,200572"))~string, "775044,,724647", "xor 16"
count = count + 1
call assertEq Oct("670027,,524335")~shl(22)~string, "506720,,000000", "shl 16"
count = count + 1
call assertEq Oct("670027,,524335")~shr(22)~string, "000000,,033401", "shr 16"
count = count + 1
call assertEq (Oct("447716,,440555") + Oct("702104,,527525"))~string, "352023,,170302", "add 17"
count = count + 1
call assertEq (Oct("447716,,440555") - Oct("702104,,527525"))~string, "545611,,711030", "sub 17"
count = count + 1
call assertEq (Oct("447716,,440555") & Oct("702104,,527525"))~string, "402104,,400505", "and 17"
count = count + 1
call assertEq (Oct("447716,,440555") | Oct("702104,,527525"))~string, "747716,,567575", "or 17"
count = count + 1
call assertEq (Oct("447716,,440555") && Oct("702104,,527525"))~string, "345612,,167070", "xor 17"
count = count + 1
call assertEq Oct("447716,,440555")~shl(37)~string, "000000,,000000", "shl 17"
count = count + 1
call assertEq Oct("447716,,440555")~shr(37)~string, "000000,,000000", "shr 17"
count = count + 1
call assertEq (Oct("657027,,305161") + Oct("013032,,561046"))~string, "672062,,066227", "add 18"
count = count + 1
call assertEq (Oct("657027,,305161") - Oct("013032,,561046"))~string, "643774,,524113", "sub 18"
count = count + 1
call assertEq (Oct("657027,,305161") & Oct("013032,,561046"))~string, "013022,,101040", "and 18"
count = count + 1
call assertEq (Oct("657027,,305161") | Oct("013032,,561046"))~string, "657037,,765167", "or 18"
count = count + 1
call assertEq (Oct("657027,,305161") && Oct("013032,,561046"))~string, "644015,,664127", "xor 18"
count = count + 1
call assertEq Oct("657027,,305161")~shl(27)~string, "161000,,000000", "shl 18"
count = count + 1
call assertEq Oct("657027,,305161")~shr(27)~string, "000000,,000657", "shr 18"
count = count + 1
call assertEq (Oct("304724,,525740") + Oct("125542,,610205"))~string, "432467,,336145", "add 19"
count = count + 1
call assertEq (Oct("304724,,525740") - Oct("125542,,610205"))~string, "157161,,715533", "sub 19"
count = count + 1
call assertEq (Oct("304724,,525740") & Oct("125542,,610205"))~string, "104500,,400200", "and 19"
count = count + 1
call assertEq (Oct("304724,,525740") | Oct("125542,,610205"))~string, "325766,,735745", "or 19"
count = count + 1
call assertEq (Oct("304724,,525740") && Oct("125542,,610205"))~string, "221266,,335545", "xor 19"
count = count + 1
call assertEq Oct("304724,,525740")~shl(18)~string, "525740,,000000", "shl 19"
count = count + 1
call assertEq Oct("304724,,525740")~shr(18)~string, "000000,,304724", "shr 19"
count = count + 1
call assertEq (Oct("260604,,161423") + Oct("530265,,663305"))~string, "011072,,044730", "add 20"
count = count + 1
call assertEq (Oct("260604,,161423") - Oct("530265,,663305"))~string, "530316,,276116", "sub 20"
count = count + 1
call assertEq (Oct("260604,,161423") & Oct("530265,,663305"))~string, "020204,,061001", "and 20"
count = count + 1
call assertEq (Oct("260604,,161423") | Oct("530265,,663305"))~string, "770665,,763727", "or 20"
count = count + 1
call assertEq (Oct("260604,,161423") && Oct("530265,,663305"))~string, "750461,,702726", "xor 20"
count = count + 1
call assertEq Oct("260604,,161423")~shl(39)~string, "000000,,000000", "shl 20"
count = count + 1
call assertEq Oct("260604,,161423")~shr(39)~string, "000000,,000000", "shr 20"
count = count + 1
call assertEq (Oct("110574,,431326") + Oct("622020,,623777"))~string, "732615,,255325", "add 21"
count = count + 1
call assertEq (Oct("110574,,431326") - Oct("622020,,623777"))~string, "266553,,605327", "sub 21"
count = count + 1
call assertEq (Oct("110574,,431326") & Oct("622020,,623777"))~string, "000020,,421326", "and 21"
count = count + 1
call assertEq (Oct("110574,,431326") | Oct("622020,,623777"))~string, "732574,,633777", "or 21"
count = count + 1
call assertEq (Oct("110574,,431326") && Oct("622020,,623777"))~string, "732554,,212451", "xor 21"
count = count + 1
call assertEq Oct("110574,,431326")~shl(32)~string, "300000,,000000", "shl 21"
count = count + 1
call assertEq Oct("110574,,431326")~shr(32)~string, "000000,,000002", "shr 21"
count = count + 1
call assertEq (Oct("151631,,531611") + Oct("255072,,407625"))~string, "426724,,141436", "add 22"
count = count + 1
call assertEq (Oct("151631,,531611") - Oct("255072,,407625"))~string, "674537,,121764", "sub 22"
count = count + 1
call assertEq (Oct("151631,,531611") & Oct("255072,,407625"))~string, "051030,,401601", "and 22"
count = count + 1
call assertEq (Oct("151631,,531611") | Oct("255072,,407625"))~string, "355673,,537635", "or 22"
count = count + 1
call assertEq (Oct("151631,,531611") && Oct("255072,,407625"))~string, "304643,,136034", "xor 22"
count = count + 1
call assertEq Oct("151631,,531611")~shl(18)~string, "531611,,000000", "shl 22"
count = count + 1
call assertEq Oct("151631,,531611")~shr(18)~string, "000000,,151631", "shr 22"
count = count + 1
call assertEq (Oct("424067,,735252") + Oct("555530,,232516"))~string, "201620,,167770", "add 23"
count = count + 1
call assertEq (Oct("424067,,735252") - Oct("555530,,232516"))~string, "646337,,502534", "sub 23"
count = count + 1
call assertEq (Oct("424067,,735252") & Oct("555530,,232516"))~string, "404020,,230012", "and 23"
count = count + 1
call assertEq (Oct("424067,,735252") | Oct("555530,,232516"))~string, "575577,,737756", "or 23"
count = count + 1
call assertEq (Oct("424067,,735252") && Oct("555530,,232516"))~string, "171557,,507744", "xor 23"
count = count + 1
call assertEq Oct("424067,,735252")~shl(6)~string, "406773,,525200", "shl 23"
count = count + 1
call assertEq Oct("424067,,735252")~shr(6)~string, "004240,,677352", "shr 23"
count = count + 1
call assertEq (Oct("626151,,767377") + Oct("602207,,774176"))~string, "430361,,763575", "add 24"
count = count + 1
call assertEq (Oct("626151,,767377") - Oct("602207,,774176"))~string, "023741,,773201", "sub 24"
count = count + 1
call assertEq (Oct("626151,,767377") & Oct("602207,,774176"))~string, "602001,,764176", "and 24"
count = count + 1
call assertEq (Oct("626151,,767377") | Oct("602207,,774176"))~string, "626357,,777377", "or 24"
count = count + 1
call assertEq (Oct("626151,,767377") && Oct("602207,,774176"))~string, "024356,,013201", "xor 24"
count = count + 1
call assertEq Oct("626151,,767377")~shl(21)~string, "673770,,000000", "shl 24"
count = count + 1
call assertEq Oct("626151,,767377")~shr(21)~string, "000000,,062615", "shr 24"
count = count + 1
call assertEq (Oct("545571,,717063") + Oct("051503,,460025"))~string, "617275,,377110", "add 25"
count = count + 1
call assertEq (Oct("545571,,717063") - Oct("051503,,460025"))~string, "474066,,237036", "sub 25"
count = count + 1
call assertEq (Oct("545571,,717063") & Oct("051503,,460025"))~string, "041501,,400021", "and 25"
count = count + 1
call assertEq (Oct("545571,,717063") | Oct("051503,,460025"))~string, "555573,,777067", "or 25"
count = count + 1
call assertEq (Oct("545571,,717063") && Oct("051503,,460025"))~string, "514072,,377046", "xor 25"
count = count + 1
call assertEq Oct("545571,,717063")~shl(35)~string, "400000,,000000", "shl 25"
count = count + 1
call assertEq Oct("545571,,717063")~shr(35)~string, "000000,,000001", "shr 25"
count = count + 1
call assertEq (Oct("076546,,575041") + Oct("072004,,402641"))~string, "170553,,177702", "add 26"
count = count + 1
call assertEq (Oct("076546,,575041") - Oct("072004,,402641"))~string, "004542,,172200", "sub 26"
count = count + 1
call assertEq (Oct("076546,,575041") & Oct("072004,,402641"))~string, "072004,,400041", "and 26"
count = count + 1
call assertEq (Oct("076546,,575041") | Oct("072004,,402641"))~string, "076546,,577641", "or 26"
count = count + 1
call assertEq (Oct("076546,,575041") && Oct("072004,,402641"))~string, "004542,,177600", "xor 26"
count = count + 1
call assertEq Oct("076546,,575041")~shl(28)~string, "102000,,000000", "shl 26"
count = count + 1
call assertEq Oct("076546,,575041")~shr(28)~string, "000000,,000037", "shr 26"
count = count + 1
call assertEq (Oct("472240,,534502") + Oct("113250,,723202"))~string, "605511,,457704", "add 27"
count = count + 1
call assertEq (Oct("472240,,534502") - Oct("113250,,723202"))~string, "356767,,611300", "sub 27"
count = count + 1
call assertEq (Oct("472240,,534502") & Oct("113250,,723202"))~string, "012240,,520002", "and 27"
count = count + 1
call assertEq (Oct("472240,,534502") | Oct("113250,,723202"))~string, "573250,,737702", "or 27"
count = count + 1
call assertEq (Oct("472240,,534502") && Oct("113250,,723202"))~string, "561010,,217700", "xor 27"
count = count + 1
call assertEq Oct("472240,,534502")~shl(3)~string, "722405,,345020", "shl 27"
count = count + 1
call assertEq Oct("472240,,534502")~shr(3)~string, "047224,,053450", "shr 27"
count = count + 1
call assertEq (Oct("674512,,213612") + Oct("310747,,362171"))~string, "205461,,576003", "add 28"
count = count + 1
call assertEq (Oct("674512,,213612") - Oct("310747,,362171"))~string, "363542,,631421", "sub 28"
count = count + 1
call assertEq (Oct("674512,,213612") & Oct("310747,,362171"))~string, "210502,,202010", "and 28"
count = count + 1
call assertEq (Oct("674512,,213612") | Oct("310747,,362171"))~string, "774757,,373773", "or 28"
count = count + 1
call assertEq (Oct("674512,,213612") && Oct("310747,,362171"))~string, "564255,,171763", "xor 28"
count = count + 1
call assertEq Oct("674512,,213612")~shl(21)~string, "136120,,000000", "shl 28"
count = count + 1
call assertEq Oct("674512,,213612")~shr(21)~string, "000000,,067451", "shr 28"
count = count + 1
call assertEq (Oct("610261,,076060") + Oct("554076,,453340"))~string, "364357,,551420", "add 29"
count = count + 1
call assertEq (Oct("610261,,076060") - Oct("554076,,453340"))~string, "034162,,422520", "sub 29"
count = count + 1
call assertEq (Oct("610261,,076060") & Oct("554076,,453340"))~string, "410060,,052040", "and 29"
count = count + 1
call assertEq (Oct("610261,,076060") | Oct("554076,,453340"))~string, "754277,,477360", "or 29"
count = count + 1
call assertEq (Oct("610261,,076060") && Oct("554076,,453340"))~string, "344217,,425320", "xor 29"
count = count + 1
call assertEq Oct("610261,,076060")~shl(39)~string, "000000,,000000", "shl 29"
count = count + 1
call assertEq Oct("610261,,076060")~shr(39)~string, "000000,,000000", "shr 29"
count = count + 1
call assertEq (Oct("277066,,351732") + Oct("353056,,125250"))~string, "652144,,477202", "add 30"
count = count + 1
call assertEq (Oct("277066,,351732") - Oct("353056,,125250"))~string, "724010,,224462", "sub 30"
count = count + 1
call assertEq (Oct("277066,,351732") & Oct("353056,,125250"))~string, "253046,,101210", "and 30"
count = count + 1
call assertEq (Oct("277066,,351732") | Oct("353056,,125250"))~string, "377076,,375772", "or 30"
count = count + 1
call assertEq (Oct("277066,,351732") && Oct("353056,,125250"))~string, "124030,,274562", "xor 30"
count = count + 1
call assertEq Oct("277066,,351732")~shl(10)~string, "154723,,664000", "shl 30"
count = count + 1
call assertEq Oct("277066,,351732")~shr(10)~string, "000137,,433164", "shr 30"
count = count + 1
call assertEq (Oct("376041,,372321") + Oct("433643,,401375"))~string, "031704,,773716", "add 31"
count = count + 1
call assertEq (Oct("376041,,372321") - Oct("433643,,401375"))~string, "742175,,770724", "sub 31"
count = count + 1
call assertEq (Oct("376041,,372321") & Oct("433643,,401375"))~string, "032041,,000321", "and 31"
count = count + 1
call assertEq (Oct("376041,,372321") | Oct("433643,,401375"))~string, "777643,,773375", "or 31"
count = count + 1
call assertEq (Oct("376041,,372321") && Oct("433643,,401375"))~string, "745602,,773054", "xor 31"
count = count + 1
call assertEq Oct("376041,,372321")~shl(15)~string, "137232,,100000", "shl 31"
count = count + 1
call assertEq Oct("376041,,372321")~shr(15)~string, "000003,,760413", "shr 31"
count = count + 1
call assertEq (Oct("516447,,210262") + Oct("504447,,170252"))~string, "223116,,400534", "add 32"
count = count + 1
call assertEq (Oct("516447,,210262") - Oct("504447,,170252"))~string, "012000,,020010", "sub 32"
count = count + 1
call assertEq (Oct("516447,,210262") & Oct("504447,,170252"))~string, "504447,,010242", "and 32"
count = count + 1
call assertEq (Oct("516447,,210262") | Oct("504447,,170252"))~string, "516447,,370272", "or 32"
count = count + 1
call assertEq (Oct("516447,,210262") && Oct("504447,,170252"))~string, "012000,,360030", "xor 32"
count = count + 1
call assertEq Oct("516447,,210262")~shl(22)~string, "205440,,000000", "shl 32"
count = count + 1
call assertEq Oct("516447,,210262")~shr(22)~string, "000000,,024722", "shr 32"
count = count + 1
call assertEq (Oct("631652,,051265") + Oct("206252,,314565"))~string, "040124,,366052", "add 33"
count = count + 1
call assertEq (Oct("631652,,051265") - Oct("206252,,314565"))~string, "423377,,534500", "sub 33"
count = count + 1
call assertEq (Oct("631652,,051265") & Oct("206252,,314565"))~string, "200252,,010065", "and 33"
count = count + 1
call assertEq (Oct("631652,,051265") | Oct("206252,,314565"))~string, "637652,,355765", "or 33"
count = count + 1
call assertEq (Oct("631652,,051265") && Oct("206252,,314565"))~string, "437400,,345700", "xor 33"
count = count + 1
call assertEq Oct("631652,,051265")~shl(34)~string, "200000,,000000", "shl 33"
count = count + 1
call assertEq Oct("631652,,051265")~shr(34)~string, "000000,,000003", "shr 33"
count = count + 1
call assertEq (Oct("556305,,540074") + Oct("730660,,645151"))~string, "507166,,405245", "add 34"
count = count + 1
call assertEq (Oct("556305,,540074") - Oct("730660,,645151"))~string, "625424,,672723", "sub 34"
count = count + 1
call assertEq (Oct("556305,,540074") & Oct("730660,,645151"))~string, "510200,,440050", "and 34"
count = count + 1
call assertEq (Oct("556305,,540074") | Oct("730660,,645151"))~string, "776765,,745175", "or 34"
count = count + 1
call assertEq (Oct("556305,,540074") && Oct("730660,,645151"))~string, "266565,,305125", "xor 34"
count = count + 1
call assertEq Oct("556305,,540074")~shl(8)~string, "142660,,036000", "shl 34"
count = count + 1
call assertEq Oct("556305,,540074")~shr(8)~string, "001334,,613300", "shr 34"
count = count + 1
call assertEq (Oct("653505,,617330") + Oct("022275,,615626"))~string, "676003,,435156", "add 35"
count = count + 1
call assertEq (Oct("653505,,617330") - Oct("022275,,615626"))~string, "631210,,001502", "sub 35"
count = count + 1
call assertEq (Oct("653505,,617330") & Oct("022275,,615626"))~string, "002005,,615220", "and 35"
count = count + 1
call assertEq (Oct("653505,,617330") | Oct("022275,,615626"))~string, "673775,,617736", "or 35"
count = count + 1
call assertEq (Oct("653505,,617330") && Oct("022275,,615626"))~string, "671770,,002516", "xor 35"
count = count + 1
call assertEq Oct("653505,,617330")~shl(16)~string, "343666,,000000", "shl 35"
count = count + 1
call assertEq Oct("653505,,617330")~shr(16)~string, "000003,,256427", "shr 35"
count = count + 1
call assertEq (Oct("076611,,675442") + Oct("363042,,425230"))~string, "461654,,322672", "add 36"
count = count + 1
call assertEq (Oct("076611,,675442") - Oct("363042,,425230"))~string, "513547,,250212", "sub 36"
count = count + 1
call assertEq (Oct("076611,,675442") & Oct("363042,,425230"))~string, "062000,,425000", "and 36"
count = count + 1
call assertEq (Oct("076611,,675442") | Oct("363042,,425230"))~string, "377653,,675672", "or 36"
count = count + 1
call assertEq (Oct("076611,,675442") && Oct("363042,,425230"))~string, "315653,,250672", "xor 36"
count = count + 1
call assertEq Oct("076611,,675442")~shl(3)~string, "766116,,754420", "shl 36"
count = count + 1
call assertEq Oct("076611,,675442")~shr(3)~string, "007661,,167544", "shr 36"
count = count + 1
call assertEq (Oct("171372,,163663") + Oct("050517,,150051"))~string, "242111,,333734", "add 37"
count = count + 1
call assertEq (Oct("171372,,163663") - Oct("050517,,150051"))~string, "120653,,013612", "sub 37"
count = count + 1
call assertEq (Oct("171372,,163663") & Oct("050517,,150051"))~string, "050112,,140041", "and 37"
count = count + 1
call assertEq (Oct("171372,,163663") | Oct("050517,,150051"))~string, "171777,,173673", "or 37"
count = count + 1
call assertEq (Oct("171372,,163663") && Oct("050517,,150051"))~string, "121665,,033632", "xor 37"
count = count + 1
call assertEq Oct("171372,,163663")~shl(8)~string, "575071,,731400", "shl 37"
count = count + 1
call assertEq Oct("171372,,163663")~shr(8)~string, "000362,,764347", "shr 37"
count = count + 1
call assertEq (Oct("023426,,410121") + Oct("406061,,443671"))~string, "431510,,054012", "add 38"
count = count + 1
call assertEq (Oct("023426,,410121") - Oct("406061,,443671"))~string, "415344,,744230", "sub 38"
count = count + 1
call assertEq (Oct("023426,,410121") & Oct("406061,,443671"))~string, "002020,,400021", "and 38"
count = count + 1
call assertEq (Oct("023426,,410121") | Oct("406061,,443671"))~string, "427467,,453771", "or 38"
count = count + 1
call assertEq (Oct("023426,,410121") && Oct("406061,,443671"))~string, "425447,,053750", "xor 38"
count = count + 1
call assertEq Oct("023426,,410121")~shl(37)~string, "000000,,000000", "shl 38"
count = count + 1
call assertEq Oct("023426,,410121")~shr(37)~string, "000000,,000000", "shr 38"
count = count + 1
call assertEq (Oct("761455,,545324") + Oct("150526,,472244"))~string, "132204,,237570", "add 39"
count = count + 1
call assertEq (Oct("761455,,545324") - Oct("150526,,472244"))~string, "610727,,053060", "sub 39"
count = count + 1
call assertEq (Oct("761455,,545324") & Oct("150526,,472244"))~string, "140404,,440204", "and 39"
count = count + 1
call assertEq (Oct("761455,,545324") | Oct("150526,,472244"))~string, "771577,,577364", "or 39"
count = count + 1
call assertEq (Oct("761455,,545324") && Oct("150526,,472244"))~string, "631173,,137160", "xor 39"
count = count + 1
call assertEq Oct("761455,,545324")~shl(35)~string, "000000,,000000", "shl 39"
count = count + 1
call assertEq Oct("761455,,545324")~shr(35)~string, "000000,,000001", "shr 39"
count = count + 1
call assertEq (Oct("516553,,471246") + Oct("154213,,624736"))~string, "672767,,316204", "add 40"
count = count + 1
call assertEq (Oct("516553,,471246") - Oct("154213,,624736"))~string, "342337,,644310", "sub 40"
count = count + 1
call assertEq (Oct("516553,,471246") & Oct("154213,,624736"))~string, "114013,,420206", "and 40"
count = count + 1
call assertEq (Oct("516553,,471246") | Oct("154213,,624736"))~string, "556753,,675776", "or 40"
count = count + 1
call assertEq (Oct("516553,,471246") && Oct("154213,,624736"))~string, "442740,,255570", "xor 40"
count = count + 1
call assertEq Oct("516553,,471246")~shl(40)~string, "000000,,000000", "shl 40"
count = count + 1
call assertEq Oct("516553,,471246")~shr(40)~string, "000000,,000000", "shr 40"
count = count + 1
call assertEq (Oct("455464,,215317") + Oct("433442,,055627"))~string, "111126,,273146", "add 41"
count = count + 1
call assertEq (Oct("455464,,215317") - Oct("433442,,055627"))~string, "022022,,137470", "sub 41"
count = count + 1
call assertEq (Oct("455464,,215317") & Oct("433442,,055627"))~string, "411440,,015207", "and 41"
count = count + 1
call assertEq (Oct("455464,,215317") | Oct("433442,,055627"))~string, "477466,,255737", "or 41"
count = count + 1
call assertEq (Oct("455464,,215317") && Oct("433442,,055627"))~string, "066026,,240530", "xor 41"
count = count + 1
call assertEq Oct("455464,,215317")~shl(10)~string, "150432,,636000", "shl 41"
count = count + 1
call assertEq Oct("455464,,215317")~shr(10)~string, "000226,,632106", "shr 41"
count = count + 1
call assertEq (Oct("560207,,203453") + Oct("615100,,514652"))~string, "375307,,720325", "add 42"
count = count + 1
call assertEq (Oct("560207,,203453") - Oct("615100,,514652"))~string, "743106,,466601", "sub 42"
count = count + 1
call assertEq (Oct("560207,,203453") & Oct("615100,,514652"))~string, "400000,,000452", "and 42"
count = count + 1
call assertEq (Oct("560207,,203453") | Oct("615100,,514652"))~string, "775307,,717653", "or 42"
count = count + 1
call assertEq (Oct("560207,,203453") && Oct("615100,,514652"))~string, "375307,,717201", "xor 42"
count = count + 1
call assertEq Oct("560207,,203453")~shl(30)~string, "530000,,000000", "shl 42"
count = count + 1
call assertEq Oct("560207,,203453")~shr(30)~string, "000000,,000056", "shr 42"
count = count + 1
call assertEq (Oct("561361,,763403") + Oct("110315,,745351"))~string, "671677,,730754", "add 43"
count = count + 1
call assertEq (Oct("561361,,763403") - Oct("110315,,745351"))~string, "451044,,016032", "sub 43"
count = count + 1
call assertEq (Oct("561361,,763403") & Oct("110315,,745351"))~string, "100301,,741001", "and 43"
count = count + 1
call assertEq (Oct("561361,,763403") | Oct("110315,,745351"))~string, "571375,,767753", "or 43"
count = count + 1
call assertEq (Oct("561361,,763403") && Oct("110315,,745351"))~string, "471074,,026752", "xor 43"
count = count + 1
call assertEq Oct("561361,,763403")~shl(39)~string, "000000,,000000", "shl 43"
count = count + 1
call assertEq Oct("561361,,763403")~shr(39)~string, "000000,,000000", "shr 43"
count = count + 1
call assertEq (Oct("013641,,466572") + Oct("044121,,463660"))~string, "057763,,152452", "add 44"
count = count + 1
call assertEq (Oct("013641,,466572") - Oct("044121,,463660"))~string, "747520,,002712", "sub 44"
count = count + 1
call assertEq (Oct("013641,,466572") & Oct("044121,,463660"))~string, "000001,,462460", "and 44"
count = count + 1
call assertEq (Oct("013641,,466572") | Oct("044121,,463660"))~string, "057761,,467772", "or 44"
count = count + 1
call assertEq (Oct("013641,,466572") && Oct("044121,,463660"))~string, "057760,,005312", "xor 44"
count = count + 1
call assertEq Oct("013641,,466572")~shl(9)~string, "641466,,572000", "shl 44"
count = count + 1
call assertEq Oct("013641,,466572")~shr(9)~string, "000013,,641466", "shr 44"
count = count + 1
call assertEq (Oct("235410,,763672") + Oct("455125,,057523"))~string, "712536,,043415", "add 45"
count = count + 1
call assertEq (Oct("235410,,763672") - Oct("455125,,057523"))~string, "560263,,704147", "sub 45"
count = count + 1
call assertEq (Oct("235410,,763672") & Oct("455125,,057523"))~string, "015000,,043422", "and 45"
count = count + 1
call assertEq (Oct("235410,,763672") | Oct("455125,,057523"))~string, "675535,,777773", "or 45"
count = count + 1
call assertEq (Oct("235410,,763672") && Oct("455125,,057523"))~string, "660535,,734351", "xor 45"
count = count + 1
call assertEq Oct("235410,,763672")~shl(1)~string, "473021,,747564", "shl 45"
count = count + 1
call assertEq Oct("235410,,763672")~shr(1)~string, "116604,,371735", "shr 45"
count = count + 1
call assertEq (Oct("757343,,331672") + Oct("204711,,631271"))~string, "164255,,163163", "add 46"
count = count + 1
call assertEq (Oct("757343,,331672") - Oct("204711,,631271"))~string, "552431,,500401", "sub 46"
count = count + 1
call assertEq (Oct("757343,,331672") & Oct("204711,,631271"))~string, "204301,,231270", "and 46"
count = count + 1
call assertEq (Oct("757343,,331672") | Oct("204711,,631271"))~string, "757753,,731673", "or 46"
count = count + 1
call assertEq (Oct("757343,,331672") && Oct("204711,,631271"))~string, "553452,,500403", "xor 46"
count = count + 1
call assertEq Oct("757343,,331672")~shl(28)~string, "564000,,000000", "shl 46"
count = count + 1
call assertEq Oct("757343,,331672")~shr(28)~string, "000000,,000367", "shr 46"
count = count + 1
call assertEq (Oct("035655,,111114") + Oct("144240,,051727"))~string, "202115,,163043", "add 47"
count = count + 1
call assertEq (Oct("035655,,111114") - Oct("144240,,051727"))~string, "671415,,037165", "sub 47"
count = count + 1
call assertEq (Oct("035655,,111114") & Oct("144240,,051727"))~string, "004240,,011104", "and 47"
count = count + 1
call assertEq (Oct("035655,,111114") | Oct("144240,,051727"))~string, "175655,,151737", "or 47"
count = count + 1
call assertEq (Oct("035655,,111114") && Oct("144240,,051727"))~string, "171415,,140633", "xor 47"
count = count + 1
call assertEq Oct("035655,,111114")~shl(27)~string, "114000,,000000", "shl 47"
count = count + 1
call assertEq Oct("035655,,111114")~shr(27)~string, "000000,,000035", "shr 47"
count = count + 1
call assertEq (Oct("666702,,746714") + Oct("257755,,340736"))~string, "146660,,307652", "add 48"
count = count + 1
call assertEq (Oct("666702,,746714") - Oct("257755,,340736"))~string, "406725,,405756", "sub 48"
count = count + 1
call assertEq (Oct("666702,,746714") & Oct("257755,,340736"))~string, "246700,,340714", "and 48"
count = count + 1
call assertEq (Oct("666702,,746714") | Oct("257755,,340736"))~string, "677757,,746736", "or 48"
count = count + 1
call assertEq (Oct("666702,,746714") && Oct("257755,,340736"))~string, "431057,,406022", "xor 48"
count = count + 1
call assertEq Oct("666702,,746714")~shl(15)~string, "274671,,400000", "shl 48"
count = count + 1
call assertEq Oct("666702,,746714")~shr(15)~string, "000006,,667027", "shr 48"
count = count + 1
call assertEq (Oct("051722,,133631") + Oct("661064,,322416"))~string, "733006,,456247", "add 49"
count = count + 1
call assertEq (Oct("051722,,133631") - Oct("661064,,322416"))~string, "170635,,611213", "sub 49"
count = count + 1
call assertEq (Oct("051722,,133631") & Oct("661064,,322416"))~string, "041020,,122410", "and 49"
count = count + 1
call assertEq (Oct("051722,,133631") | Oct("661064,,322416"))~string, "671766,,333637", "or 49"
count = count + 1
call assertEq (Oct("051722,,133631") && Oct("661064,,322416"))~string, "630746,,211227", "xor 49"
count = count + 1
call assertEq Oct("051722,,133631")~shl(40)~string, "000000,,000000", "shl 49"
count = count + 1
call assertEq Oct("051722,,133631")~shr(40)~string, "000000,,000000", "shr 49"
count = count + 1
call assertEq (Oct("710074,,170251") + Oct("166043,,705544"))~string, "076140,,076015", "add 50"
count = count + 1
call assertEq (Oct("710074,,170251") - Oct("166043,,705544"))~string, "522030,,262505", "sub 50"
count = count + 1
call assertEq (Oct("710074,,170251") & Oct("166043,,705544"))~string, "100040,,100040", "and 50"
count = count + 1
call assertEq (Oct("710074,,170251") | Oct("166043,,705544"))~string, "776077,,775755", "or 50"
count = count + 1
call assertEq (Oct("710074,,170251") && Oct("166043,,705544"))~string, "676037,,675715", "xor 50"
count = count + 1
call assertEq Oct("710074,,170251")~shl(21)~string, "702510,,000000", "shl 50"
count = count + 1
call assertEq Oct("710074,,170251")~shr(21)~string, "000000,,071007", "shr 50"
count = count + 1
call assertEq (Oct("155163,,470272") + Oct("621555,,415503"))~string, "776741,,105775", "add 51"
count = count + 1
call assertEq (Oct("155163,,470272") - Oct("621555,,415503"))~string, "333406,,052567", "sub 51"
count = count + 1
call assertEq (Oct("155163,,470272") & Oct("621555,,415503"))~string, "001141,,410002", "and 51"
count = count + 1
call assertEq (Oct("155163,,470272") | Oct("621555,,415503"))~string, "775577,,475773", "or 51"
count = count + 1
call assertEq (Oct("155163,,470272") && Oct("621555,,415503"))~string, "774436,,065771", "xor 51"
count = count + 1
call assertEq Oct("155163,,470272")~shl(10)~string, "347160,,564000", "shl 51"
count = count + 1
call assertEq Oct("155163,,470272")~shr(10)~string, "000066,,471634", "shr 51"
count = count + 1
call assertEq (Oct("404025,,631625") + Oct("416666,,343170"))~string, "022714,,175015", "add 52"
count = count + 1
call assertEq (Oct("404025,,631625") - Oct("416666,,343170"))~string, "765137,,266435", "sub 52"
count = count + 1
call assertEq (Oct("404025,,631625") & Oct("416666,,343170"))~string, "404024,,201020", "and 52"
count = count + 1
call assertEq (Oct("404025,,631625") | Oct("416666,,343170"))~string, "416667,,773775", "or 52"
count = count + 1
call assertEq (Oct("404025,,631625") && Oct("416666,,343170"))~string, "012643,,572755", "xor 52"
count = count + 1
call assertEq Oct("404025,,631625")~shl(18)~string, "631625,,000000", "shl 52"
count = count + 1
call assertEq Oct("404025,,631625")~shr(18)~string, "000000,,404025", "shr 52"
count = count + 1
call assertEq (Oct("334015,,253171") + Oct("102336,,212074"))~string, "436353,,465265", "add 53"
count = count + 1
call assertEq (Oct("334015,,253171") - Oct("102336,,212074"))~string, "231457,,041075", "sub 53"
count = count + 1
call assertEq (Oct("334015,,253171") & Oct("102336,,212074"))~string, "100014,,212070", "and 53"
count = count + 1
call assertEq (Oct("334015,,253171") | Oct("102336,,212074"))~string, "336337,,253175", "or 53"
count = count + 1
call assertEq (Oct("334015,,253171") && Oct("102336,,212074"))~string, "236323,,041105", "xor 53"
count = count + 1
call assertEq Oct("334015,,253171")~shl(17)~string, "525474,,400000", "shl 53"
count = count + 1
call assertEq Oct("334015,,253171")~shr(17)~string, "000000,,670032", "shr 53"
count = count + 1
call assertEq (Oct("400021,,225433") + Oct("542054,,376101"))~string, "142075,,623534", "add 54"
count = count + 1
call assertEq (Oct("400021,,225433") - Oct("542054,,376101"))~string, "635744,,627332", "sub 54"
count = count + 1
call assertEq (Oct("400021,,225433") & Oct("542054,,376101"))~string, "400000,,224001", "and 54"
count = count + 1
call assertEq (Oct("400021,,225433") | Oct("542054,,376101"))~string, "542075,,377533", "or 54"
count = count + 1
call assertEq (Oct("400021,,225433") && Oct("542054,,376101"))~string, "142075,,153532", "xor 54"
count = count + 1
call assertEq Oct("400021,,225433")~shl(14)~string, "051261,,540000", "shl 54"
count = count + 1
call assertEq Oct("400021,,225433")~shr(14)~string, "000010,,000424", "shr 54"
count = count + 1
call assertEq (Oct("030652,,324341") + Oct("036675,,641037"))~string, "067550,,165400", "add 55"
count = count + 1
call assertEq (Oct("030652,,324341") - Oct("036675,,641037"))~string, "771754,,463302", "sub 55"
count = count + 1
call assertEq (Oct("030652,,324341") & Oct("036675,,641037"))~string, "030650,,200001", "and 55"
count = count + 1
call assertEq (Oct("030652,,324341") | Oct("036675,,641037"))~string, "036677,,765377", "or 55"
count = count + 1
call assertEq (Oct("030652,,324341") && Oct("036675,,641037"))~string, "006027,,565376", "xor 55"
count = count + 1
call assertEq Oct("030652,,324341")~shl(3)~string, "306523,,243410", "shl 55"
count = count + 1
call assertEq Oct("030652,,324341")~shr(3)~string, "003065,,232434", "shr 55"
count = count + 1
call assertEq (Oct("347763,,553404") + Oct("437707,,032160"))~string, "007672,,605564", "add 56"
count = count + 1
call assertEq (Oct("347763,,553404") - Oct("437707,,032160"))~string, "710054,,521224", "sub 56"
count = count + 1
call assertEq (Oct("347763,,553404") & Oct("437707,,032160"))~string, "007703,,012000", "and 56"
count = count + 1
call assertEq (Oct("347763,,553404") | Oct("437707,,032160"))~string, "777767,,573564", "or 56"
count = count + 1
call assertEq (Oct("347763,,553404") && Oct("437707,,032160"))~string, "770064,,561564", "xor 56"
count = count + 1
call assertEq Oct("347763,,553404")~shl(0)~string, "347763,,553404", "shl 56"
count = count + 1
call assertEq Oct("347763,,553404")~shr(0)~string, "347763,,553404", "shr 56"
count = count + 1
call assertEq (Oct("220556,,567472") + Oct("726633,,104635"))~string, "147411,,674327", "add 57"
count = count + 1
call assertEq (Oct("220556,,567472") - Oct("726633,,104635"))~string, "271723,,462635", "sub 57"
count = count + 1
call assertEq (Oct("220556,,567472") & Oct("726633,,104635"))~string, "220412,,104430", "and 57"
count = count + 1
call assertEq (Oct("220556,,567472") | Oct("726633,,104635"))~string, "726777,,567677", "or 57"
count = count + 1
call assertEq (Oct("220556,,567472") && Oct("726633,,104635"))~string, "506365,,463247", "xor 57"
count = count + 1
call assertEq Oct("220556,,567472")~shl(25)~string, "716400,,000000", "shl 57"
count = count + 1
call assertEq Oct("220556,,567472")~shr(25)~string, "000000,,001102", "shr 57"
count = count + 1
call assertEq (Oct("302461,,457020") + Oct("477206,,300334"))~string, "001667,,757354", "add 58"
count = count + 1
call assertEq (Oct("302461,,457020") - Oct("477206,,300334"))~string, "603253,,156464", "sub 58"
count = count + 1
call assertEq (Oct("302461,,457020") & Oct("477206,,300334"))~string, "002000,,000020", "and 58"
count = count + 1
call assertEq (Oct("302461,,457020") | Oct("477206,,300334"))~string, "777667,,757334", "or 58"
count = count + 1
call assertEq (Oct("302461,,457020") && Oct("477206,,300334"))~string, "775667,,757314", "xor 58"
count = count + 1
call assertEq Oct("302461,,457020")~shl(22)~string, "360400,,000000", "shl 58"
count = count + 1
call assertEq Oct("302461,,457020")~shr(22)~string, "000000,,014123", "shr 58"
count = count + 1
call assertEq (Oct("524564,,565724") + Oct("254116,,056653"))~string, "000702,,644577", "add 59"
count = count + 1
call assertEq (Oct("524564,,565724") - Oct("254116,,056653"))~string, "250446,,507051", "sub 59"
count = count + 1
call assertEq (Oct("524564,,565724") & Oct("254116,,056653"))~string, "004104,,044600", "and 59"
count = count + 1
call assertEq (Oct("524564,,565724") | Oct("254116,,056653"))~string, "774576,,577777", "or 59"
count = count + 1
call assertEq (Oct("524564,,565724") && Oct("254116,,056653"))~string, "770472,,533177", "xor 59"
count = count + 1
call assertEq Oct("524564,,565724")~shl(10)~string, "351353,,650000", "shl 59"
count = count + 1
call assertEq Oct("524564,,565724")~shr(10)~string, "000252,,272272", "shr 59"
count = count + 1
call assertEq (Oct("153500,,452054") + Oct("253072,,310334"))~string, "426572,,762410", "add 60"
count = count + 1
call assertEq (Oct("153500,,452054") - Oct("253072,,310334"))~string, "700406,,141520", "sub 60"
count = count + 1
call assertEq (Oct("153500,,452054") & Oct("253072,,310334"))~string, "053000,,010014", "and 60"
count = count + 1
call assertEq (Oct("153500,,452054") | Oct("253072,,310334"))~string, "353572,,752374", "or 60"
count = count + 1
call assertEq (Oct("153500,,452054") && Oct("253072,,310334"))~string, "300572,,742360", "xor 60"
count = count + 1
call assertEq Oct("153500,,452054")~shl(9)~string, "500452,,054000", "shl 60"
count = count + 1
call assertEq Oct("153500,,452054")~shr(9)~string, "000153,,500452", "shr 60"
count = count + 1
call assertEq (Oct("136076,,760453") + Oct("522754,,076713"))~string, "661053,,057366", "add 61"
count = count + 1
call assertEq (Oct("136076,,760453") - Oct("522754,,076713"))~string, "413122,,661540", "sub 61"
count = count + 1
call assertEq (Oct("136076,,760453") & Oct("522754,,076713"))~string, "122054,,060413", "and 61"
count = count + 1
call assertEq (Oct("136076,,760453") | Oct("522754,,076713"))~string, "536776,,776753", "or 61"
count = count + 1
call assertEq (Oct("136076,,760453") && Oct("522754,,076713"))~string, "414722,,716340", "xor 61"
count = count + 1
call assertEq Oct("136076,,760453")~shl(32)~string, "540000,,000000", "shl 61"
count = count + 1
call assertEq Oct("136076,,760453")~shr(32)~string, "000000,,000002", "shr 61"
count = count + 1
call assertEq (Oct("615463,,740731") + Oct("712557,,155556"))~string, "530243,,116507", "add 62"
count = count + 1
call assertEq (Oct("615463,,740731") - Oct("712557,,155556"))~string, "702704,,563153", "sub 62"
count = count + 1
call assertEq (Oct("615463,,740731") & Oct("712557,,155556"))~string, "610443,,140510", "and 62"
count = count + 1
call assertEq (Oct("615463,,740731") | Oct("712557,,155556"))~string, "717577,,755777", "or 62"
count = count + 1
call assertEq (Oct("615463,,740731") && Oct("712557,,155556"))~string, "107134,,615267", "xor 62"
count = count + 1
call assertEq Oct("615463,,740731")~shl(26)~string, "354400,,000000", "shl 62"
count = count + 1
call assertEq Oct("615463,,740731")~shr(26)~string, "000000,,001433", "shr 62"
count = count + 1
call assertEq (Oct("012600,,442676") + Oct("741753,,103575"))~string, "754553,,546473", "add 63"
count = count + 1
call assertEq (Oct("012600,,442676") - Oct("741753,,103575"))~string, "050625,,337101", "sub 63"
count = count + 1
call assertEq (Oct("012600,,442676") & Oct("741753,,103575"))~string, "000600,,002474", "and 63"
count = count + 1
call assertEq (Oct("012600,,442676") | Oct("741753,,103575"))~string, "753753,,543777", "or 63"
count = count + 1
call assertEq (Oct("012600,,442676") && Oct("741753,,103575"))~string, "753153,,541303", "xor 63"
count = count + 1
call assertEq Oct("012600,,442676")~shl(22)~string, "055740,,000000", "shl 63"
count = count + 1
call assertEq Oct("012600,,442676")~shr(22)~string, "000000,,000530", "shr 63"
count = count + 1
call assertEq (Oct("265104,,756336") + Oct("204110,,510415"))~string, "471215,,466753", "add 64"
count = count + 1
call assertEq (Oct("265104,,756336") - Oct("204110,,510415"))~string, "060774,,245721", "sub 64"
count = count + 1
call assertEq (Oct("265104,,756336") & Oct("204110,,510415"))~string, "204100,,510014", "and 64"
count = count + 1
call assertEq (Oct("265104,,756336") | Oct("204110,,510415"))~string, "265114,,756737", "or 64"
count = count + 1
call assertEq (Oct("265104,,756336") && Oct("204110,,510415"))~string, "061014,,246723", "xor 64"
count = count + 1
call assertEq Oct("265104,,756336")~shl(1)~string, "552211,,734674", "shl 64"
count = count + 1
call assertEq Oct("265104,,756336")~shr(1)~string, "132442,,367157", "shr 64"
count = count + 1
call assertEq (Oct("122506,,634665") + Oct("061552,,162031"))~string, "204261,,016716", "add 65"
count = count + 1
call assertEq (Oct("122506,,634665") - Oct("061552,,162031"))~string, "040734,,452634", "sub 65"
count = count + 1
call assertEq (Oct("122506,,634665") & Oct("061552,,162031"))~string, "020502,,020021", "and 65"
count = count + 1
call assertEq (Oct("122506,,634665") | Oct("061552,,162031"))~string, "163556,,776675", "or 65"
count = count + 1
call assertEq (Oct("122506,,634665") && Oct("061552,,162031"))~string, "143054,,756654", "xor 65"
count = count + 1
call assertEq Oct("122506,,634665")~shl(36)~string, "000000,,000000", "shl 65"
count = count + 1
call assertEq Oct("122506,,634665")~shr(36)~string, "000000,,000000", "shr 65"
count = count + 1
call assertEq (Oct("751540,,232521") + Oct("332731,,415745"))~string, "304471,,650466", "add 66"
count = count + 1
call assertEq (Oct("751540,,232521") - Oct("332731,,415745"))~string, "416606,,614554", "sub 66"
count = count + 1
call assertEq (Oct("751540,,232521") & Oct("332731,,415745"))~string, "310500,,010501", "and 66"
count = count + 1
call assertEq (Oct("751540,,232521") | Oct("332731,,415745"))~string, "773771,,637765", "or 66"
count = count + 1
call assertEq (Oct("751540,,232521") && Oct("332731,,415745"))~string, "463271,,627264", "xor 66"
count = count + 1
call assertEq Oct("751540,,232521")~shl(33)~string, "100000,,000000", "shl 66"
count = count + 1
call assertEq Oct("751540,,232521")~shr(33)~string, "000000,,000007", "shr 66"
count = count + 1
call assertEq (Oct("005022,,050305") + Oct("300453,,336364"))~string, "305475,,406671", "add 67"
count = count + 1
call assertEq (Oct("005022,,050305") - Oct("300453,,336364"))~string, "504346,,511721", "sub 67"
count = count + 1
call assertEq (Oct("005022,,050305") & Oct("300453,,336364"))~string, "000002,,010304", "and 67"
count = count + 1
call assertEq (Oct("005022,,050305") | Oct("300453,,336364"))~string, "305473,,376365", "or 67"
count = count + 1
call assertEq (Oct("005022,,050305") && Oct("300453,,336364"))~string, "305471,,366061", "xor 67"
count = count + 1
call assertEq Oct("005022,,050305")~shl(0)~string, "005022,,050305", "shl 67"
count = count + 1
call assertEq Oct("005022,,050305")~shr(0)~string, "005022,,050305", "shr 67"
count = count + 1
call assertEq (Oct("314050,,556521") + Oct("772635,,401015"))~string, "306706,,157536", "add 68"
count = count + 1
call assertEq (Oct("314050,,556521") - Oct("772635,,401015"))~string, "321213,,155504", "sub 68"
count = count + 1
call assertEq (Oct("314050,,556521") & Oct("772635,,401015"))~string, "310010,,400001", "and 68"
count = count + 1
call assertEq (Oct("314050,,556521") | Oct("772635,,401015"))~string, "776675,,557535", "or 68"
count = count + 1
call assertEq (Oct("314050,,556521") && Oct("772635,,401015"))~string, "466665,,157534", "xor 68"
count = count + 1
call assertEq Oct("314050,,556521")~shl(26)~string, "250400,,000000", "shl 68"
count = count + 1
call assertEq Oct("314050,,556521")~shr(26)~string, "000000,,000630", "shr 68"
count = count + 1
call assertEq (Oct("727665,,462405") + Oct("442164,,225503"))~string, "372051,,710110", "add 69"
count = count + 1
call assertEq (Oct("727665,,462405") - Oct("442164,,225503"))~string, "265501,,234702", "sub 69"
count = count + 1
call assertEq (Oct("727665,,462405") & Oct("442164,,225503"))~string, "402064,,020401", "and 69"
count = count + 1
call assertEq (Oct("727665,,462405") | Oct("442164,,225503"))~string, "767765,,667507", "or 69"
count = count + 1
call assertEq (Oct("727665,,462405") && Oct("442164,,225503"))~string, "365701,,647106", "xor 69"
count = count + 1
call assertEq Oct("727665,,462405")~shl(0)~string, "727665,,462405", "shl 69"
count = count + 1
call assertEq Oct("727665,,462405")~shr(0)~string, "727665,,462405", "shr 69"
count = count + 1
call assertEq (Oct("604124,,642305") + Oct("433774,,160717"))~string, "240121,,023224", "add 70"
count = count + 1
call assertEq (Oct("604124,,642305") - Oct("433774,,160717"))~string, "150130,,461366", "sub 70"
count = count + 1
call assertEq (Oct("604124,,642305") & Oct("433774,,160717"))~string, "400124,,040305", "and 70"
count = count + 1
call assertEq (Oct("604124,,642305") | Oct("433774,,160717"))~string, "637774,,762717", "or 70"
count = count + 1
call assertEq (Oct("604124,,642305") && Oct("433774,,160717"))~string, "237650,,722412", "xor 70"
count = count + 1
call assertEq Oct("604124,,642305")~shl(12)~string, "246423,,050000", "shl 70"
count = count + 1
call assertEq Oct("604124,,642305")~shr(12)~string, "000060,,412464", "shr 70"
count = count + 1
call assertEq (Oct("204613,,733221") + Oct("413755,,731153"))~string, "620571,,664374", "add 71"
count = count + 1
call assertEq (Oct("204613,,733221") - Oct("413755,,731153"))~string, "570636,,002046", "sub 71"
count = count + 1
call assertEq (Oct("204613,,733221") & Oct("413755,,731153"))~string, "000611,,731001", "and 71"
count = count + 1
call assertEq (Oct("204613,,733221") | Oct("413755,,731153"))~string, "617757,,733373", "or 71"
count = count + 1
call assertEq (Oct("204613,,733221") && Oct("413755,,731153"))~string, "617146,,002372", "xor 71"
count = count + 1
call assertEq Oct("204613,,733221")~shl(35)~string, "400000,,000000", "shl 71"
count = count + 1
call assertEq Oct("204613,,733221")~shr(35)~string, "000000,,000000", "shr 71"
count = count + 1
call assertEq (Oct("444646,,270045") + Oct("215407,,706627"))~string, "662256,,176674", "add 72"
count = count + 1
call assertEq (Oct("444646,,270045") - Oct("215407,,706627"))~string, "227236,,361216", "sub 72"
count = count + 1
call assertEq (Oct("444646,,270045") & Oct("215407,,706627"))~string, "004406,,200005", "and 72"
count = count + 1
call assertEq (Oct("444646,,270045") | Oct("215407,,706627"))~string, "655647,,776667", "or 72"
count = count + 1
call assertEq (Oct("444646,,270045") && Oct("215407,,706627"))~string, "651241,,576662", "xor 72"
count = count + 1
call assertEq Oct("444646,,270045")~shl(11)~string, "231340,,224000", "shl 72"
count = count + 1
call assertEq Oct("444646,,270045")~shr(11)~string, "000111,,151456", "shr 72"
count = count + 1
call assertEq (Oct("010342,,535142") + Oct("730274,,652650"))~string, "740637,,410012", "add 73"
count = count + 1
call assertEq (Oct("010342,,535142") - Oct("730274,,652650"))~string, "060045,,662272", "sub 73"
count = count + 1
call assertEq (Oct("010342,,535142") & Oct("730274,,652650"))~string, "010240,,410040", "and 73"
count = count + 1
call assertEq (Oct("010342,,535142") | Oct("730274,,652650"))~string, "730376,,777752", "or 73"
count = count + 1
call assertEq (Oct("010342,,535142") && Oct("730274,,652650"))~string, "720136,,367712", "xor 73"
count = count + 1
call assertEq Oct("010342,,535142")~shl(40)~string, "000000,,000000", "shl 73"
count = count + 1
call assertEq Oct("010342,,535142")~shr(40)~string, "000000,,000000", "shr 73"
count = count + 1
call assertEq (Oct("171265,,324507") + Oct("227102,,377040"))~string, "420367,,723547", "add 74"
count = count + 1
call assertEq (Oct("171265,,324507") - Oct("227102,,377040"))~string, "742162,,725447", "sub 74"
count = count + 1
call assertEq (Oct("171265,,324507") & Oct("227102,,377040"))~string, "021000,,324000", "and 74"
count = count + 1
call assertEq (Oct("171265,,324507") | Oct("227102,,377040"))~string, "377367,,377547", "or 74"
count = count + 1
call assertEq (Oct("171265,,324507") && Oct("227102,,377040"))~string, "356367,,053547", "xor 74"
count = count + 1
call assertEq Oct("171265,,324507")~shl(26)~string, "243400,,000000", "shl 74"
count = count + 1
call assertEq Oct("171265,,324507")~shr(26)~string, "000000,,000362", "shr 74"
count = count + 1
call assertEq (Oct("035356,,161610") + Oct("735013,,324537"))~string, "772371,,506347", "add 75"
count = count + 1
call assertEq (Oct("035356,,161610") - Oct("735013,,324537"))~string, "100342,,635051", "sub 75"
count = count + 1
call assertEq (Oct("035356,,161610") & Oct("735013,,324537"))~string, "035012,,120410", "and 75"
count = count + 1
call assertEq (Oct("035356,,161610") | Oct("735013,,324537"))~string, "735357,,365737", "or 75"
count = count + 1
call assertEq (Oct("035356,,161610") && Oct("735013,,324537"))~string, "700345,,245327", "xor 75"
count = count + 1
call assertEq Oct("035356,,161610")~shl(20)~string, "707040,,000000", "shl 75"
count = count + 1
call assertEq Oct("035356,,161610")~shr(20)~string, "000000,,007273", "shr 75"
count = count + 1
call assertEq (Oct("112661,,622271") + Oct("743052,,631150"))~string, "055734,,453441", "add 76"
count = count + 1
call assertEq (Oct("112661,,622271") - Oct("743052,,631150"))~string, "147606,,771121", "sub 76"
count = count + 1
call assertEq (Oct("112661,,622271") & Oct("743052,,631150"))~string, "102040,,620050", "and 76"
count = count + 1
call assertEq (Oct("112661,,622271") | Oct("743052,,631150"))~string, "753673,,633371", "or 76"
count = count + 1
call assertEq (Oct("112661,,622271") && Oct("743052,,631150"))~string, "651633,,013321", "xor 76"
count = count + 1
call assertEq Oct("112661,,622271")~shl(13)~string, "434445,,620000", "shl 76"
count = count + 1
call assertEq Oct("112661,,622271")~shr(13)~string, "000004,,533071", "shr 76"
count = count + 1
call assertEq (Oct("701701,,610501") + Oct("077214,,647251"))~string, "001116,,457752", "add 77"
count = count + 1
call assertEq (Oct("701701,,610501") - Oct("077214,,647251"))~string, "602464,,741230", "sub 77"
count = count + 1
call assertEq (Oct("701701,,610501") & Oct("077214,,647251"))~string, "001200,,600001", "and 77"
count = count + 1
call assertEq (Oct("701701,,610501") | Oct("077214,,647251"))~string, "777715,,657751", "or 77"
count = count + 1
call assertEq (Oct("701701,,610501") && Oct("077214,,647251"))~string, "776515,,057750", "xor 77"
count = count + 1
call assertEq Oct("701701,,610501")~shl(13)~string, "034212,,020000", "shl 77"
count = count + 1
call assertEq Oct("701701,,610501")~shr(13)~string, "000034,,074070", "shr 77"
count = count + 1
call assertEq (Oct("523611,,557315") + Oct("512557,,676573"))~string, "236371,,456110", "add 78"
count = count + 1
call assertEq (Oct("523611,,557315") - Oct("512557,,676573"))~string, "011031,,660522", "sub 78"
count = count + 1
call assertEq (Oct("523611,,557315") & Oct("512557,,676573"))~string, "502411,,456111", "and 78"
count = count + 1
call assertEq (Oct("523611,,557315") | Oct("512557,,676573"))~string, "533757,,777777", "or 78"
count = count + 1
call assertEq (Oct("523611,,557315") && Oct("512557,,676573"))~string, "031346,,321666", "xor 78"
count = count + 1
call assertEq Oct("523611,,557315")~shl(14)~string, "466754,,640000", "shl 78"
count = count + 1
call assertEq Oct("523611,,557315")~shr(14)~string, "000012,,474233", "shr 78"
count = count + 1
call assertEq (Oct("173160,,053172") + Oct("615574,,517012"))~string, "010754,,572204", "add 79"
count = count + 1
call assertEq (Oct("173160,,053172") - Oct("615574,,517012"))~string, "355363,,334160", "sub 79"
count = count + 1
call assertEq (Oct("173160,,053172") & Oct("615574,,517012"))~string, "011160,,013012", "and 79"
count = count + 1
call assertEq (Oct("173160,,053172") | Oct("615574,,517012"))~string, "777574,,557172", "or 79"
count = count + 1
call assertEq (Oct("173160,,053172") && Oct("615574,,517012"))~string, "766414,,544160", "xor 79"
count = count + 1
call assertEq Oct("173160,,053172")~shl(12)~string, "600531,,720000", "shl 79"
count = count + 1
call assertEq Oct("173160,,053172")~shr(12)~string, "000017,,316005", "shr 79"
count = count + 1
call assertEq (Oct("706506,,106762") + Oct("657264,,533457"))~string, "565772,,642441", "add 80"
count = count + 1
call assertEq (Oct("706506,,106762") - Oct("657264,,533457"))~string, "027221,,353303", "sub 80"
count = count + 1
call assertEq (Oct("706506,,106762") & Oct("657264,,533457"))~string, "606004,,102442", "and 80"
count = count + 1
call assertEq (Oct("706506,,106762") | Oct("657264,,533457"))~string, "757766,,537777", "or 80"
count = count + 1
call assertEq (Oct("706506,,106762") && Oct("657264,,533457"))~string, "151762,,435335", "xor 80"
count = count + 1
call assertEq Oct("706506,,106762")~shl(1)~string, "615214,,215744", "shl 80"
count = count + 1
call assertEq Oct("706506,,106762")~shr(1)~string, "343243,,043371", "shr 80"
count = count + 1
call assertEq (Oct("344254,,271532") + Oct("741121,,237473"))~string, "305375,,531225", "add 81"
count = count + 1
call assertEq (Oct("344254,,271532") - Oct("741121,,237473"))~string, "403133,,032037", "sub 81"
count = count + 1
call assertEq (Oct("344254,,271532") & Oct("741121,,237473"))~string, "340000,,231432", "and 81"
count = count + 1
call assertEq (Oct("344254,,271532") | Oct("741121,,237473"))~string, "745375,,277573", "or 81"
count = count + 1
call assertEq (Oct("344254,,271532") && Oct("741121,,237473"))~string, "405375,,046141", "xor 81"
count = count + 1
call assertEq Oct("344254,,271532")~shl(1)~string, "710530,,563264", "shl 81"
count = count + 1
call assertEq Oct("344254,,271532")~shr(1)~string, "162126,,134655", "shr 81"
count = count + 1
call assertEq (Oct("750577,,002711") + Oct("551664,,113457"))~string, "522463,,116370", "add 82"
count = count + 1
call assertEq (Oct("750577,,002711") - Oct("551664,,113457"))~string, "176712,,667232", "sub 82"
count = count + 1
call assertEq (Oct("750577,,002711") & Oct("551664,,113457"))~string, "550464,,002411", "and 82"
count = count + 1
call assertEq (Oct("750577,,002711") | Oct("551664,,113457"))~string, "751777,,113757", "or 82"
count = count + 1
call assertEq (Oct("750577,,002711") && Oct("551664,,113457"))~string, "201313,,111346", "xor 82"
count = count + 1
call assertEq Oct("750577,,002711")~shl(21)~string, "027110,,000000", "shl 82"
count = count + 1
call assertEq Oct("750577,,002711")~shr(21)~string, "000000,,075057", "shr 82"
count = count + 1
call assertEq (Oct("733655,,775554") + Oct("515305,,553615"))~string, "451163,,551371", "add 83"
count = count + 1
call assertEq (Oct("733655,,775554") - Oct("515305,,553615"))~string, "216350,,221737", "sub 83"
count = count + 1
call assertEq (Oct("733655,,775554") & Oct("515305,,553615"))~string, "511205,,551414", "and 83"
count = count + 1
call assertEq (Oct("733655,,775554") | Oct("515305,,553615"))~string, "737755,,777755", "or 83"
count = count + 1
call assertEq (Oct("733655,,775554") && Oct("515305,,553615"))~string, "226550,,226341", "xor 83"
count = count + 1
call assertEq Oct("733655,,775554")~shl(26)~string, "666000,,000000", "shl 83"
count = count + 1
call assertEq Oct("733655,,775554")~shr(26)~string, "000000,,001667", "shr 83"
count = count + 1
call assertEq (Oct("632616,,321435") + Oct("353071,,515261"))~string, "205710,,036716", "add 84"
count = count + 1
call assertEq (Oct("632616,,321435") - Oct("353071,,515261"))~string, "257524,,604154", "sub 84"
count = count + 1
call assertEq (Oct("632616,,321435") & Oct("353071,,515261"))~string, "212010,,101021", "and 84"
count = count + 1
call assertEq (Oct("632616,,321435") | Oct("353071,,515261"))~string, "773677,,735675", "or 84"
count = count + 1
call assertEq (Oct("632616,,321435") && Oct("353071,,515261"))~string, "561667,,634654", "xor 84"
count = count + 1
call assertEq Oct("632616,,321435")~shl(8)~string, "307150,,616400", "shl 84"
count = count + 1
call assertEq Oct("632616,,321435")~shr(8)~string, "001465,,434643", "shr 84"
count = count + 1
call assertEq (Oct("561753,,317762") + Oct("412307,,151427"))~string, "174262,,471411", "add 85"
count = count + 1
call assertEq (Oct("561753,,317762") - Oct("412307,,151427"))~string, "147444,,146333", "sub 85"
count = count + 1
call assertEq (Oct("561753,,317762") & Oct("412307,,151427"))~string, "400303,,111422", "and 85"
count = count + 1
call assertEq (Oct("561753,,317762") | Oct("412307,,151427"))~string, "573757,,357767", "or 85"
count = count + 1
call assertEq (Oct("561753,,317762") && Oct("412307,,151427"))~string, "173454,,246345", "xor 85"
count = count + 1
call assertEq Oct("561753,,317762")~shl(0)~string, "561753,,317762", "shl 85"
count = count + 1
call assertEq Oct("561753,,317762")~shr(0)~string, "561753,,317762", "shr 85"
count = count + 1
call assertEq (Oct("072274,,171613") + Oct("226066,,746001"))~string, "320363,,137614", "add 86"
count = count + 1
call assertEq (Oct("072274,,171613") - Oct("226066,,746001"))~string, "644205,,223612", "sub 86"
count = count + 1
call assertEq (Oct("072274,,171613") & Oct("226066,,746001"))~string, "022064,,140001", "and 86"
count = count + 1
call assertEq (Oct("072274,,171613") | Oct("226066,,746001"))~string, "276276,,777613", "or 86"
count = count + 1
call assertEq (Oct("072274,,171613") && Oct("226066,,746001"))~string, "254212,,637612", "xor 86"
count = count + 1
call assertEq Oct("072274,,171613")~shl(1)~string, "164570,,363426", "shl 86"
count = count + 1
call assertEq Oct("072274,,171613")~shr(1)~string, "035136,,074705", "shr 86"
count = count + 1
call assertEq (Oct("762514,,657557") + Oct("262204,,250311"))~string, "244721,,130070", "add 87"
count = count + 1
call assertEq (Oct("762514,,657557") - Oct("262204,,250311"))~string, "500310,,407246", "sub 87"
count = count + 1
call assertEq (Oct("762514,,657557") & Oct("262204,,250311"))~string, "262004,,250111", "and 87"
count = count + 1
call assertEq (Oct("762514,,657557") | Oct("262204,,250311"))~string, "762714,,657757", "or 87"
count = count + 1
call assertEq (Oct("762514,,657557") && Oct("262204,,250311"))~string, "500710,,407646", "xor 87"
count = count + 1
call assertEq Oct("762514,,657557")~shl(12)~string, "146575,,570000", "shl 87"
count = count + 1
call assertEq Oct("762514,,657557")~shr(12)~string, "000076,,251465", "shr 87"
count = count + 1
call assertEq (Oct("316705,,226107") + Oct("467274,,570274"))~string, "006202,,016403", "add 88"
count = count + 1
call assertEq (Oct("316705,,226107") - Oct("467274,,570274"))~string, "627410,,435613", "sub 88"
count = count + 1
call assertEq (Oct("316705,,226107") & Oct("467274,,570274"))~string, "006204,,020004", "and 88"
count = count + 1
call assertEq (Oct("316705,,226107") | Oct("467274,,570274"))~string, "777775,,776377", "or 88"
count = count + 1
call assertEq (Oct("316705,,226107") && Oct("467274,,570274"))~string, "771571,,756373", "xor 88"
count = count + 1
call assertEq Oct("316705,,226107")~shl(16)~string, "245421,,600000", "shl 88"
count = count + 1
call assertEq Oct("316705,,226107")~shr(16)~string, "000001,,473425", "shr 88"
count = count + 1
call assertEq (Oct("737625,,762715") + Oct("443606,,276526"))~string, "403434,,261443", "add 89"
count = count + 1
call assertEq (Oct("737625,,762715") - Oct("443606,,276526"))~string, "274017,,464167", "sub 89"
count = count + 1
call assertEq (Oct("737625,,762715") & Oct("443606,,276526"))~string, "403604,,262504", "and 89"
count = count + 1
call assertEq (Oct("737625,,762715") | Oct("443606,,276526"))~string, "777627,,776737", "or 89"
count = count + 1
call assertEq (Oct("737625,,762715") && Oct("443606,,276526"))~string, "374023,,514233", "xor 89"
count = count + 1
call assertEq Oct("737625,,762715")~shl(19)~string, "745632,,000000", "shl 89"
count = count + 1
call assertEq Oct("737625,,762715")~shr(19)~string, "000000,,357712", "shr 89"
count = count + 1
call assertEq (Oct("745200,,713650") + Oct("570674,,605713"))~string, "536075,,521563", "add 90"
count = count + 1
call assertEq (Oct("745200,,713650") - Oct("570674,,605713"))~string, "154304,,105735", "sub 90"
count = count + 1
call assertEq (Oct("745200,,713650") & Oct("570674,,605713"))~string, "540200,,601610", "and 90"
count = count + 1
call assertEq (Oct("745200,,713650") | Oct("570674,,605713"))~string, "775674,,717753", "or 90"
count = count + 1
call assertEq (Oct("745200,,713650") && Oct("570674,,605713"))~string, "235474,,116143", "xor 90"
count = count + 1
call assertEq Oct("745200,,713650")~shl(30)~string, "500000,,000000", "shl 90"
count = count + 1
call assertEq Oct("745200,,713650")~shr(30)~string, "000000,,000074", "shr 90"
count = count + 1
call assertEq (Oct("453011,,021301") + Oct("517136,,231656"))~string, "172147,,253157", "add 91"
count = count + 1
call assertEq (Oct("453011,,021301") - Oct("517136,,231656"))~string, "733652,,567423", "sub 91"
count = count + 1
call assertEq (Oct("453011,,021301") & Oct("517136,,231656"))~string, "413010,,021200", "and 91"
count = count + 1
call assertEq (Oct("453011,,021301") | Oct("517136,,231656"))~string, "557137,,231757", "or 91"
count = count + 1
call assertEq (Oct("453011,,021301") && Oct("517136,,231656"))~string, "144127,,210557", "xor 91"
count = count + 1
call assertEq Oct("453011,,021301")~shl(4)~string, "260220,,426020", "shl 91"
count = count + 1
call assertEq Oct("453011,,021301")~shr(4)~string, "022540,,441054", "shr 91"
count = count + 1
call assertEq (Oct("026446,,544663") + Oct("451452,,511575"))~string, "500121,,256460", "add 92"
count = count + 1
call assertEq (Oct("026446,,544663") - Oct("451452,,511575"))~string, "354774,,033066", "sub 92"
count = count + 1
call assertEq (Oct("026446,,544663") & Oct("451452,,511575"))~string, "000442,,500461", "and 92"
count = count + 1
call assertEq (Oct("026446,,544663") | Oct("451452,,511575"))~string, "477456,,555777", "or 92"
count = count + 1
call assertEq (Oct("026446,,544663") && Oct("451452,,511575"))~string, "477014,,055316", "xor 92"
count = count + 1
call assertEq Oct("026446,,544663")~shl(40)~string, "000000,,000000", "shl 92"
count = count + 1
call assertEq Oct("026446,,544663")~shr(40)~string, "000000,,000000", "shr 92"
count = count + 1
call assertEq (Oct("411631,,172460") + Oct("374513,,460157"))~string, "006344,,652637", "add 93"
count = count + 1
call assertEq (Oct("411631,,172460") - Oct("374513,,460157"))~string, "015115,,512301", "sub 93"
count = count + 1
call assertEq (Oct("411631,,172460") & Oct("374513,,460157"))~string, "010411,,060040", "and 93"
count = count + 1
call assertEq (Oct("411631,,172460") | Oct("374513,,460157"))~string, "775733,,572577", "or 93"
count = count + 1
call assertEq (Oct("411631,,172460") && Oct("374513,,460157"))~string, "765322,,512537", "xor 93"
count = count + 1
call assertEq Oct("411631,,172460")~shl(11)~string, "144752,,300000", "shl 93"
count = count + 1
call assertEq Oct("411631,,172460")~shr(11)~string, "000102,,346236", "shr 93"
count = count + 1
call assertEq (Oct("564420,,467100") + Oct("203602,,347145"))~string, "770223,,036245", "add 94"
count = count + 1
call assertEq (Oct("564420,,467100") - Oct("203602,,347145"))~string, "360616,,117733", "sub 94"
count = count + 1
call assertEq (Oct("564420,,467100") & Oct("203602,,347145"))~string, "000400,,047100", "and 94"
count = count + 1
call assertEq (Oct("564420,,467100") | Oct("203602,,347145"))~string, "767622,,767145", "or 94"
count = count + 1
call assertEq (Oct("564420,,467100") && Oct("203602,,347145"))~string, "767222,,720045", "xor 94"
count = count + 1
call assertEq Oct("564420,,467100")~shl(19)~string, "156200,,000000", "shl 94"
count = count + 1
call assertEq Oct("564420,,467100")~shr(19)~string, "000000,,272210", "shr 94"
count = count + 1
call assertEq (Oct("474345,,143733") + Oct("342651,,007247"))~string, "037216,,153202", "add 95"
count = count + 1
call assertEq (Oct("474345,,143733") - Oct("342651,,007247"))~string, "131474,,134464", "sub 95"
count = count + 1
call assertEq (Oct("474345,,143733") & Oct("342651,,007247"))~string, "040241,,003203", "and 95"
count = count + 1
call assertEq (Oct("474345,,143733") | Oct("342651,,007247"))~string, "776755,,147777", "or 95"
count = count + 1
call assertEq (Oct("474345,,143733") && Oct("342651,,007247"))~string, "736514,,144574", "xor 95"
count = count + 1
call assertEq Oct("474345,,143733")~shl(15)~string, "514373,,300000", "shl 95"
count = count + 1
call assertEq Oct("474345,,143733")~shr(15)~string, "000004,,743451", "shr 95"
count = count + 1
call assertEq (Oct("552174,,444027") + Oct("127123,,072702"))~string, "701317,,536731", "add 96"
count = count + 1
call assertEq (Oct("552174,,444027") - Oct("127123,,072702"))~string, "423051,,351125", "sub 96"
count = count + 1
call assertEq (Oct("552174,,444027") & Oct("127123,,072702"))~string, "102120,,040002", "and 96"
count = count + 1
call assertEq (Oct("552174,,444027") | Oct("127123,,072702"))~string, "577177,,476727", "or 96"
count = count + 1
call assertEq (Oct("552174,,444027") && Oct("127123,,072702"))~string, "475057,,436725", "xor 96"
count = count + 1
call assertEq Oct("552174,,444027")~shl(20)~string, "220134,,000000", "shl 96"
count = count + 1
call assertEq Oct("552174,,444027")~shr(20)~string, "000000,,132437", "shr 96"
count = count + 1
call assertEq (Oct("100154,,012627") + Oct("765122,,250357"))~string, "065276,,263206", "add 97"
count = count + 1
call assertEq (Oct("100154,,012627") - Oct("765122,,250357"))~string, "113031,,542250", "sub 97"
count = count + 1
call assertEq (Oct("100154,,012627") & Oct("765122,,250357"))~string, "100100,,010207", "and 97"
count = count + 1
call assertEq (Oct("100154,,012627") | Oct("765122,,250357"))~string, "765176,,252777", "or 97"
count = count + 1
call assertEq (Oct("100154,,012627") && Oct("765122,,250357"))~string, "665076,,242570", "xor 97"
count = count + 1
call assertEq Oct("100154,,012627")~shl(31)~string, "560000,,000000", "shl 97"
count = count + 1
call assertEq Oct("100154,,012627")~shr(31)~string, "000000,,000004", "shr 97"
count = count + 1
call assertEq (Oct("662627,,153042") + Oct("247326,,175264"))~string, "132155,,350326", "add 98"
count = count + 1
call assertEq (Oct("662627,,153042") - Oct("247326,,175264"))~string, "413300,,755556", "sub 98"
count = count + 1
call assertEq (Oct("662627,,153042") & Oct("247326,,175264"))~string, "242226,,151040", "and 98"
count = count + 1
call assertEq (Oct("662627,,153042") | Oct("247326,,175264"))~string, "667727,,177266", "or 98"
count = count + 1
call assertEq (Oct("662627,,153042") && Oct("247326,,175264"))~string, "425501,,026226", "xor 98"
count = count + 1
call assertEq Oct("662627,,153042")~shl(7)~string, "545632,,610400", "shl 98"
count = count + 1
call assertEq Oct("662627,,153042")~shr(7)~string, "003313,,134654", "shr 98"
count = count + 1
call assertEq (Oct("465416,,535174") + Oct("012642,,266451"))~string, "500261,,023645", "add 99"
count = count + 1
call assertEq (Oct("465416,,535174") - Oct("012642,,266451"))~string, "452554,,246523", "sub 99"
count = count + 1
call assertEq (Oct("465416,,535174") & Oct("012642,,266451"))~string, "000402,,024050", "and 99"
count = count + 1
call assertEq (Oct("465416,,535174") | Oct("012642,,266451"))~string, "477656,,777575", "or 99"
count = count + 1
call assertEq (Oct("465416,,535174") && Oct("012642,,266451"))~string, "477254,,753525", "xor 99"
count = count + 1
call assertEq Oct("465416,,535174")~shl(26)~string, "476000,,000000", "shl 99"
count = count + 1
call assertEq Oct("465416,,535174")~shr(26)~string, "000000,,001153", "shr 99"
count = count + 1
call assertEq (Oct("764355,,725415") + Oct("357753,,216164"))~string, "344331,,143601", "add 100"
count = count + 1
call assertEq (Oct("764355,,725415") - Oct("357753,,216164"))~string, "404402,,507231", "sub 100"
count = count + 1
call assertEq (Oct("764355,,725415") & Oct("357753,,216164"))~string, "344351,,204004", "and 100"
count = count + 1
call assertEq (Oct("764355,,725415") | Oct("357753,,216164"))~string, "777757,,737575", "or 100"
count = count + 1
call assertEq (Oct("764355,,725415") && Oct("357753,,216164"))~string, "433406,,533571", "xor 100"
count = count + 1
call assertEq Oct("764355,,725415")~shl(40)~string, "000000,,000000", "shl 100"
count = count + 1
call assertEq Oct("764355,,725415")~shr(40)~string, "000000,,000000", "shr 100"
count = count + 1
call assertEq (Oct("600423,,546133") + Oct("421131,,450156"))~string, "221555,,216311", "add 101"
count = count + 1
call assertEq (Oct("600423,,546133") - Oct("421131,,450156"))~string, "157272,,075755", "sub 101"
count = count + 1
call assertEq (Oct("600423,,546133") & Oct("421131,,450156"))~string, "400021,,440112", "and 101"
count = count + 1
call assertEq (Oct("600423,,546133") | Oct("421131,,450156"))~string, "621533,,556177", "or 101"
count = count + 1
call assertEq (Oct("600423,,546133") && Oct("421131,,450156"))~string, "221512,,116065", "xor 101"
count = count + 1
call assertEq Oct("600423,,546133")~shl(16)~string, "731426,,600000", "shl 101"
count = count + 1
call assertEq Oct("600423,,546133")~shr(16)~string, "000003,,002116", "shr 101"
count = count + 1
call assertEq (Oct("507234,,621153") + Oct("307337,,101712"))~string, "016573,,723065", "add 102"
count = count + 1
call assertEq (Oct("507234,,621153") - Oct("307337,,101712"))~string, "177675,,517241", "sub 102"
count = count + 1
call assertEq (Oct("507234,,621153") & Oct("307337,,101712"))~string, "107234,,001112", "and 102"
count = count + 1
call assertEq (Oct("507234,,621153") | Oct("307337,,101712"))~string, "707337,,721753", "or 102"
count = count + 1
call assertEq (Oct("507234,,621153") && Oct("307337,,101712"))~string, "600103,,720641", "xor 102"
count = count + 1
call assertEq Oct("507234,,621153")~shl(4)~string, "164714,,423260", "shl 102"
count = count + 1
call assertEq Oct("507234,,621153")~shr(4)~string, "024351,,631046", "shr 102"
count = count + 1
call assertEq (Oct("173570,,515571") + Oct("142573,,531553"))~string, "336364,,247344", "add 103"
count = count + 1
call assertEq (Oct("173570,,515571") - Oct("142573,,531553"))~string, "030774,,764016", "sub 103"
count = count + 1
call assertEq (Oct("173570,,515571") & Oct("142573,,531553"))~string, "142570,,511551", "and 103"
count = count + 1
call assertEq (Oct("173570,,515571") | Oct("142573,,531553"))~string, "173573,,535573", "or 103"
count = count + 1
call assertEq (Oct("173570,,515571") && Oct("142573,,531553"))~string, "031003,,024022", "xor 103"
count = count + 1
call assertEq Oct("173570,,515571")~shl(25)~string, "336200,,000000", "shl 103"
count = count + 1
call assertEq Oct("173570,,515571")~shr(25)~string, "000000,,000756", "shr 103"
count = count + 1
call assertEq (Oct("554245,,462327") + Oct("160343,,572733"))~string, "734611,,255262", "add 104"
count = count + 1
call assertEq (Oct("554245,,462327") - Oct("160343,,572733"))~string, "373701,,667374", "sub 104"
count = count + 1
call assertEq (Oct("554245,,462327") & Oct("160343,,572733"))~string, "140241,,462323", "and 104"
count = count + 1
call assertEq (Oct("554245,,462327") | Oct("160343,,572733"))~string, "574347,,572737", "or 104"
count = count + 1
call assertEq (Oct("554245,,462327") && Oct("160343,,572733"))~string, "434106,,110414", "xor 104"
count = count + 1
call assertEq Oct("554245,,462327")~shl(5)~string, "612263,,115340", "shl 104"
count = count + 1
call assertEq Oct("554245,,462327")~shr(5)~string, "013305,,131446", "shr 104"
count = count + 1
call assertEq (Oct("762160,,405076") + Oct("627575,,247467"))~string, "611755,,654565", "add 105"
count = count + 1
call assertEq (Oct("762160,,405076") - Oct("627575,,247467"))~string, "132363,,135407", "sub 105"
count = count + 1
call assertEq (Oct("762160,,405076") & Oct("627575,,247467"))~string, "622160,,005066", "and 105"
count = count + 1
call assertEq (Oct("762160,,405076") | Oct("627575,,247467"))~string, "767575,,647477", "or 105"
count = count + 1
call assertEq (Oct("762160,,405076") && Oct("627575,,247467"))~string, "145415,,642411", "xor 105"
count = count + 1
call assertEq Oct("762160,,405076")~shl(35)~string, "000000,,000000", "shl 105"
count = count + 1
call assertEq Oct("762160,,405076")~shr(35)~string, "000000,,000001", "shr 105"
count = count + 1
call assertEq (Oct("746440,,537317") + Oct("732627,,305447"))~string, "701270,,044766", "add 106"
count = count + 1
call assertEq (Oct("746440,,537317") - Oct("732627,,305447"))~string, "013611,,231650", "sub 106"
count = count + 1
call assertEq (Oct("746440,,537317") & Oct("732627,,305447"))~string, "702400,,105007", "and 106"
count = count + 1
call assertEq (Oct("746440,,537317") | Oct("732627,,305447"))~string, "776667,,737757", "or 106"
count = count + 1
call assertEq (Oct("746440,,537317") && Oct("732627,,305447"))~string, "074267,,632750", "xor 106"
count = count + 1
call assertEq Oct("746440,,537317")~shl(5)~string, "322025,,754740", "shl 106"
count = count + 1
call assertEq Oct("746440,,537317")~shr(5)~string, "017151,,012766", "shr 106"
count = count + 1
call assertEq (Oct("001752,,150676") + Oct("474566,,021771"))~string, "476540,,172667", "add 107"
count = count + 1
call assertEq (Oct("001752,,150676") - Oct("474566,,021771"))~string, "305164,,126705", "sub 107"
count = count + 1
call assertEq (Oct("001752,,150676") & Oct("474566,,021771"))~string, "000542,,000670", "and 107"
count = count + 1
call assertEq (Oct("001752,,150676") | Oct("474566,,021771"))~string, "475776,,171777", "or 107"
count = count + 1
call assertEq (Oct("001752,,150676") && Oct("474566,,021771"))~string, "475234,,171107", "xor 107"
count = count + 1
call assertEq Oct("001752,,150676")~shl(7)~string, "372432,,157400", "shl 107"
count = count + 1
call assertEq Oct("001752,,150676")~shr(7)~string, "000007,,650643", "shr 107"
count = count + 1
call assertEq (Oct("115361,,633051") + Oct("634145,,142716"))~string, "751526,,775767", "add 108"
count = count + 1
call assertEq (Oct("115361,,633051") - Oct("634145,,142716"))~string, "261214,,470133", "sub 108"
count = count + 1
call assertEq (Oct("115361,,633051") & Oct("634145,,142716"))~string, "014141,,002010", "and 108"
count = count + 1
call assertEq (Oct("115361,,633051") | Oct("634145,,142716"))~string, "735365,,773757", "or 108"
count = count + 1
call assertEq (Oct("115361,,633051") && Oct("634145,,142716"))~string, "721224,,771747", "xor 108"
count = count + 1
call assertEq Oct("115361,,633051")~shl(16)~string, "346612,,200000", "shl 108"
count = count + 1
call assertEq Oct("115361,,633051")~shr(16)~string, "000000,,465707", "shr 108"
count = count + 1
call assertEq (Oct("740120,,101714") + Oct("473235,,344254"))~string, "433355,,446170", "add 109"
count = count + 1
call assertEq (Oct("740120,,101714") - Oct("473235,,344254"))~string, "244662,,535440", "sub 109"
count = count + 1
call assertEq (Oct("740120,,101714") & Oct("473235,,344254"))~string, "440020,,100214", "and 109"
count = count + 1
call assertEq (Oct("740120,,101714") | Oct("473235,,344254"))~string, "773335,,345754", "or 109"
count = count + 1
call assertEq (Oct("740120,,101714") && Oct("473235,,344254"))~string, "333315,,245540", "xor 109"
count = count + 1
call assertEq Oct("740120,,101714")~shl(8)~string, "050040,,746000", "shl 109"
count = count + 1
call assertEq Oct("740120,,101714")~shr(8)~string, "001700,,240203", "shr 109"
count = count + 1
call assertEq (Oct("741343,,246051") + Oct("535200,,570215"))~string, "476544,,036266", "add 110"
count = count + 1
call assertEq (Oct("741343,,246051") - Oct("535200,,570215"))~string, "204142,,455634", "sub 110"
count = count + 1
call assertEq (Oct("741343,,246051") & Oct("535200,,570215"))~string, "501200,,040011", "and 110"
count = count + 1
call assertEq (Oct("741343,,246051") | Oct("535200,,570215"))~string, "775343,,776255", "or 110"
count = count + 1
call assertEq (Oct("741343,,246051") && Oct("535200,,570215"))~string, "274143,,736244", "xor 110"
count = count + 1
call assertEq Oct("741343,,246051")~shl(24)~string, "605100,,000000", "shl 110"
count = count + 1
call assertEq Oct("741343,,246051")~shr(24)~string, "000000,,007413", "shr 110"
count = count + 1
call assertEq (Oct("246427,,363421") + Oct("403603,,063416"))~string, "652232,,447037", "add 111"
count = count + 1
call assertEq (Oct("246427,,363421") - Oct("403603,,063416"))~string, "642624,,300003", "sub 111"
count = count + 1
call assertEq (Oct("246427,,363421") & Oct("403603,,063416"))~string, "002403,,063400", "and 111"
count = count + 1
call assertEq (Oct("246427,,363421") | Oct("403603,,063416"))~string, "647627,,363437", "or 111"
count = count + 1
call assertEq (Oct("246427,,363421") && Oct("403603,,063416"))~string, "645224,,300037", "xor 111"
count = count + 1
call assertEq Oct("246427,,363421")~shl(29)~string, "104000,,000000", "shl 111"
count = count + 1
call assertEq Oct("246427,,363421")~shr(29)~string, "000000,,000051", "shr 111"
count = count + 1
call assertEq (Oct("370470,,745371") + Oct("241540,,775447"))~string, "632231,,743040", "add 112"
count = count + 1
call assertEq (Oct("370470,,745371") - Oct("241540,,775447"))~string, "126727,,747722", "sub 112"
count = count + 1
call assertEq (Oct("370470,,745371") & Oct("241540,,775447"))~string, "240440,,745041", "and 112"
count = count + 1
call assertEq (Oct("370470,,745371") | Oct("241540,,775447"))~string, "371570,,775777", "or 112"
count = count + 1
call assertEq (Oct("370470,,745371") && Oct("241540,,775447"))~string, "131130,,030736", "xor 112"
count = count + 1
call assertEq Oct("370470,,745371")~shl(20)~string, "625744,,000000", "shl 112"
count = count + 1
call assertEq Oct("370470,,745371")~shr(20)~string, "000000,,076116", "shr 112"
count = count + 1
call assertEq (Oct("350745,,133735") + Oct("022454,,026225"))~string, "373421,,162162", "add 113"
count = count + 1
call assertEq (Oct("350745,,133735") - Oct("022454,,026225"))~string, "326271,,105510", "sub 113"
count = count + 1
call assertEq (Oct("350745,,133735") & Oct("022454,,026225"))~string, "000444,,022225", "and 113"
count = count + 1
call assertEq (Oct("350745,,133735") | Oct("022454,,026225"))~string, "372755,,137735", "or 113"
count = count + 1
call assertEq (Oct("350745,,133735") && Oct("022454,,026225"))~string, "372311,,115510", "xor 113"
count = count + 1
call assertEq Oct("350745,,133735")~shl(36)~string, "000000,,000000", "shl 113"
count = count + 1
call assertEq Oct("350745,,133735")~shr(36)~string, "000000,,000000", "shr 113"
count = count + 1
call assertEq (Oct("753351,,120356") + Oct("425473,,505102"))~string, "401044,,625460", "add 114"
count = count + 1
call assertEq (Oct("753351,,120356") - Oct("425473,,505102"))~string, "325655,,413254", "sub 114"
count = count + 1
call assertEq (Oct("753351,,120356") & Oct("425473,,505102"))~string, "401051,,100102", "and 114"
count = count + 1
call assertEq (Oct("753351,,120356") | Oct("425473,,505102"))~string, "777773,,525356", "or 114"
count = count + 1
call assertEq (Oct("753351,,120356") && Oct("425473,,505102"))~string, "376722,,425254", "xor 114"
count = count + 1
call assertEq Oct("753351,,120356")~shl(33)~string, "600000,,000000", "shl 114"
count = count + 1
call assertEq Oct("753351,,120356")~shr(33)~string, "000000,,000007", "shr 114"
count = count + 1
call assertEq (Oct("354267,,167272") + Oct("463640,,715223"))~string, "040130,,104515", "add 115"
count = count + 1
call assertEq (Oct("354267,,167272") - Oct("463640,,715223"))~string, "670426,,252047", "sub 115"
count = count + 1
call assertEq (Oct("354267,,167272") & Oct("463640,,715223"))~string, "040240,,105222", "and 115"
count = count + 1
call assertEq (Oct("354267,,167272") | Oct("463640,,715223"))~string, "777667,,777273", "or 115"
count = count + 1
call assertEq (Oct("354267,,167272") && Oct("463640,,715223"))~string, "737427,,672051", "xor 115"
count = count + 1
call assertEq Oct("354267,,167272")~shl(22)~string, "565640,,000000", "shl 115"
count = count + 1
call assertEq Oct("354267,,167272")~shr(22)~string, "000000,,016613", "shr 115"
count = count + 1
call assertEq (Oct("121215,,207177") + Oct("260725,,026467"))~string, "402142,,235666", "add 116"
count = count + 1
call assertEq (Oct("121215,,207177") - Oct("260725,,026467"))~string, "640270,,160510", "sub 116"
count = count + 1
call assertEq (Oct("121215,,207177") & Oct("260725,,026467"))~string, "020205,,006067", "and 116"
count = count + 1
call assertEq (Oct("121215,,207177") | Oct("260725,,026467"))~string, "361735,,227577", "or 116"
count = count + 1
call assertEq (Oct("121215,,207177") && Oct("260725,,026467"))~string, "341530,,221510", "xor 116"
count = count + 1
call assertEq Oct("121215,,207177")~shl(21)~string, "071770,,000000", "shl 116"
count = count + 1
call assertEq Oct("121215,,207177")~shr(21)~string, "000000,,012121", "shr 116"
count = count + 1
call assertEq (Oct("732247,,522331") + Oct("650727,,447700"))~string, "603177,,172231", "add 117"
count = count + 1
call assertEq (Oct("732247,,522331") - Oct("650727,,447700"))~string, "061320,,052431", "sub 117"
count = count + 1
call assertEq (Oct("732247,,522331") & Oct("650727,,447700"))~string, "610207,,402300", "and 117"
count = count + 1
call assertEq (Oct("732247,,522331") | Oct("650727,,447700"))~string, "772767,,567731", "or 117"
count = count + 1
call assertEq (Oct("732247,,522331") && Oct("650727,,447700"))~string, "162560,,165431", "xor 117"
count = count + 1
call assertEq Oct("732247,,522331")~shl(0)~string, "732247,,522331", "shl 117"
count = count + 1
call assertEq Oct("732247,,522331")~shr(0)~string, "732247,,522331", "shr 117"
count = count + 1
call assertEq (Oct("001001,,331450") + Oct("663632,,332341"))~string, "664633,,664011", "add 118"
count = count + 1
call assertEq (Oct("001001,,331450") - Oct("663632,,332341"))~string, "115146,,777107", "sub 118"
count = count + 1
call assertEq (Oct("001001,,331450") & Oct("663632,,332341"))~string, "001000,,330040", "and 118"
count = count + 1
call assertEq (Oct("001001,,331450") | Oct("663632,,332341"))~string, "663633,,333751", "or 118"
count = count + 1
call assertEq (Oct("001001,,331450") && Oct("663632,,332341"))~string, "662633,,003711", "xor 118"
count = count + 1
call assertEq Oct("001001,,331450")~shl(40)~string, "000000,,000000", "shl 118"
count = count + 1
call assertEq Oct("001001,,331450")~shr(40)~string, "000000,,000000", "shr 118"
count = count + 1
call assertEq (Oct("274777,,454702") + Oct("427404,,671300"))~string, "724404,,346202", "add 119"
count = count + 1
call assertEq (Oct("274777,,454702") - Oct("427404,,671300"))~string, "645372,,563402", "sub 119"
count = count + 1
call assertEq (Oct("274777,,454702") & Oct("427404,,671300"))~string, "024404,,450300", "and 119"
count = count + 1
call assertEq (Oct("274777,,454702") | Oct("427404,,671300"))~string, "677777,,675702", "or 119"
count = count + 1
call assertEq (Oct("274777,,454702") && Oct("427404,,671300"))~string, "653373,,225402", "xor 119"
count = count + 1
call assertEq Oct("274777,,454702")~shl(33)~string, "200000,,000000", "shl 119"
count = count + 1
call assertEq Oct("274777,,454702")~shr(33)~string, "000000,,000002", "shr 119"
count = count + 1
call assertEq (Oct("646670,,445612") + Oct("514343,,026565"))~string, "363233,,474377", "add 120"
count = count + 1
call assertEq (Oct("646670,,445612") - Oct("514343,,026565"))~string, "132325,,417025", "sub 120"
count = count + 1
call assertEq (Oct("646670,,445612") & Oct("514343,,026565"))~string, "404240,,004400", "and 120"
count = count + 1
call assertEq (Oct("646670,,445612") | Oct("514343,,026565"))~string, "756773,,467777", "or 120"
count = count + 1
call assertEq (Oct("646670,,445612") && Oct("514343,,026565"))~string, "352533,,463377", "xor 120"
count = count + 1
call assertEq Oct("646670,,445612")~shl(1)~string, "515561,,113424", "shl 120"
count = count + 1
call assertEq Oct("646670,,445612")~shr(1)~string, "323334,,222705", "shr 120"
count = count + 1
call assertEq (Oct("624024,,434310") + Oct("117310,,222161"))~string, "743334,,656471", "add 121"
count = count + 1
call assertEq (Oct("624024,,434310") - Oct("117310,,222161"))~string, "504514,,212127", "sub 121"
count = count + 1
call assertEq (Oct("624024,,434310") & Oct("117310,,222161"))~string, "004000,,020100", "and 121"
count = count + 1
call assertEq (Oct("624024,,434310") | Oct("117310,,222161"))~string, "737334,,636371", "or 121"
count = count + 1
call assertEq (Oct("624024,,434310") && Oct("117310,,222161"))~string, "733334,,616271", "xor 121"
count = count + 1
call assertEq Oct("624024,,434310")~shl(38)~string, "000000,,000000", "shl 121"
count = count + 1
call assertEq Oct("624024,,434310")~shr(38)~string, "000000,,000000", "shr 121"
count = count + 1
call assertEq (Oct("767570,,540461") + Oct("211502,,555673"))~string, "201273,,316354", "add 122"
count = count + 1
call assertEq (Oct("767570,,540461") - Oct("211502,,555673"))~string, "556065,,762566", "sub 122"
count = count + 1
call assertEq (Oct("767570,,540461") & Oct("211502,,555673"))~string, "201500,,540461", "and 122"
count = count + 1
call assertEq (Oct("767570,,540461") | Oct("211502,,555673"))~string, "777572,,555673", "or 122"
count = count + 1
call assertEq (Oct("767570,,540461") && Oct("211502,,555673"))~string, "576072,,015212", "xor 122"
count = count + 1
call assertEq Oct("767570,,540461")~shl(2)~string, "736742,,602304", "shl 122"
count = count + 1
call assertEq Oct("767570,,540461")~shr(2)~string, "175736,,130114", "shr 122"
count = count + 1
call assertEq (Oct("513102,,624720") + Oct("757342,,150633"))~string, "472444,,775553", "add 123"
count = count + 1
call assertEq (Oct("513102,,624720") - Oct("757342,,150633"))~string, "533540,,454065", "sub 123"
count = count + 1
call assertEq (Oct("513102,,624720") & Oct("757342,,150633"))~string, "513102,,000620", "and 123"
count = count + 1
call assertEq (Oct("513102,,624720") | Oct("757342,,150633"))~string, "757342,,774733", "or 123"
count = count + 1
call assertEq (Oct("513102,,624720") && Oct("757342,,150633"))~string, "244240,,774113", "xor 123"
count = count + 1
call assertEq Oct("513102,,624720")~shl(35)~string, "000000,,000000", "shl 123"
count = count + 1
call assertEq Oct("513102,,624720")~shr(35)~string, "000000,,000001", "shr 123"
count = count + 1
call assertEq (Oct("422667,,760624") + Oct("352263,,603311"))~string, "775153,,564135", "add 124"
count = count + 1
call assertEq (Oct("422667,,760624") - Oct("352263,,603311"))~string, "050404,,155313", "sub 124"
count = count + 1
call assertEq (Oct("422667,,760624") & Oct("352263,,603311"))~string, "002263,,600200", "and 124"
count = count + 1
call assertEq (Oct("422667,,760624") | Oct("352263,,603311"))~string, "772667,,763735", "or 124"
count = count + 1
call assertEq (Oct("422667,,760624") && Oct("352263,,603311"))~string, "770404,,163535", "xor 124"
count = count + 1
call assertEq Oct("422667,,760624")~shl(9)~string, "667760,,624000", "shl 124"
count = count + 1
call assertEq Oct("422667,,760624")~shr(9)~string, "000422,,667760", "shr 124"
count = count + 1
call assertEq (Oct("252701,,370675") + Oct("220547,,635233"))~string, "473451,,226130", "add 125"
count = count + 1
call assertEq (Oct("252701,,370675") - Oct("220547,,635233"))~string, "032131,,533442", "sub 125"
count = count + 1
call assertEq (Oct("252701,,370675") & Oct("220547,,635233"))~string, "200501,,230231", "and 125"
count = count + 1
call assertEq (Oct("252701,,370675") | Oct("220547,,635233"))~string, "272747,,775677", "or 125"
count = count + 1
call assertEq (Oct("252701,,370675") && Oct("220547,,635233"))~string, "072246,,545446", "xor 125"
count = count + 1
call assertEq Oct("252701,,370675")~shl(34)~string, "200000,,000000", "shl 125"
count = count + 1
call assertEq Oct("252701,,370675")~shr(34)~string, "000000,,000001", "shr 125"
count = count + 1
call assertEq (Oct("662054,,666032") + Oct("107401,,726355"))~string, "771456,,614407", "add 126"
count = count + 1
call assertEq (Oct("662054,,666032") - Oct("107401,,726355"))~string, "552452,,737455", "sub 126"
count = count + 1
call assertEq (Oct("662054,,666032") & Oct("107401,,726355"))~string, "002000,,626010", "and 126"
count = count + 1
call assertEq (Oct("662054,,666032") | Oct("107401,,726355"))~string, "767455,,766377", "or 126"
count = count + 1
call assertEq (Oct("662054,,666032") && Oct("107401,,726355"))~string, "765455,,140367", "xor 126"
count = count + 1
call assertEq Oct("662054,,666032")~shl(2)~string, "310263,,330150", "shl 126"
count = count + 1
call assertEq Oct("662054,,666032")~shr(2)~string, "154413,,155406", "shr 126"
count = count + 1
call assertEq (Oct("364356,,344122") + Oct("675204,,612244"))~string, "261563,,156366", "add 127"
count = count + 1
call assertEq (Oct("364356,,344122") - Oct("675204,,612244"))~string, "467151,,531656", "sub 127"
count = count + 1
call assertEq (Oct("364356,,344122") & Oct("675204,,612244"))~string, "264204,,200000", "and 127"
count = count + 1
call assertEq (Oct("364356,,344122") | Oct("675204,,612244"))~string, "775356,,756366", "or 127"
count = count + 1
call assertEq (Oct("364356,,344122") && Oct("675204,,612244"))~string, "511152,,556366", "xor 127"
count = count + 1
call assertEq Oct("364356,,344122")~shl(17)~string, "162051,,000000", "shl 127"
count = count + 1
call assertEq Oct("364356,,344122")~shr(17)~string, "000000,,750734", "shr 127"
count = count + 1
call assertEq (Oct("472746,,115775") + Oct("230420,,503070"))~string, "723366,,621065", "add 128"
count = count + 1
call assertEq (Oct("472746,,115775") - Oct("230420,,503070"))~string, "242325,,412705", "sub 128"
count = count + 1
call assertEq (Oct("472746,,115775") & Oct("230420,,503070"))~string, "030400,,101070", "and 128"
count = count + 1
call assertEq (Oct("472746,,115775") | Oct("230420,,503070"))~string, "672766,,517775", "or 128"
count = count + 1
call assertEq (Oct("472746,,115775") && Oct("230420,,503070"))~string, "642366,,416705", "xor 128"
count = count + 1
call assertEq Oct("472746,,115775")~shl(36)~string, "000000,,000000", "shl 128"
count = count + 1
call assertEq Oct("472746,,115775")~shr(36)~string, "000000,,000000", "shr 128"
count = count + 1
call assertEq (Oct("671753,,234515") + Oct("241232,,202056"))~string, "133205,,436573", "add 129"
count = count + 1
call assertEq (Oct("671753,,234515") - Oct("241232,,202056"))~string, "430521,,032437", "sub 129"
count = count + 1
call assertEq (Oct("671753,,234515") & Oct("241232,,202056"))~string, "241212,,200014", "and 129"
count = count + 1
call assertEq (Oct("671753,,234515") | Oct("241232,,202056"))~string, "671773,,236557", "or 129"
count = count + 1
call assertEq (Oct("671753,,234515") && Oct("241232,,202056"))~string, "430561,,036543", "xor 129"
count = count + 1
call assertEq Oct("671753,,234515")~shl(18)~string, "234515,,000000", "shl 129"
count = count + 1
call assertEq Oct("671753,,234515")~shr(18)~string, "000000,,671753", "shr 129"
count = count + 1
call assertEq (Oct("430632,,155526") + Oct("421714,,650065"))~string, "052547,,025613", "add 130"
count = count + 1
call assertEq (Oct("430632,,155526") - Oct("421714,,650065"))~string, "006715,,305441", "sub 130"
count = count + 1
call assertEq (Oct("430632,,155526") & Oct("421714,,650065"))~string, "420610,,050024", "and 130"
count = count + 1
call assertEq (Oct("430632,,155526") | Oct("421714,,650065"))~string, "431736,,755567", "or 130"
count = count + 1
call assertEq (Oct("430632,,155526") && Oct("421714,,650065"))~string, "011126,,705543", "xor 130"
count = count + 1
call assertEq Oct("430632,,155526")~shl(12)~string, "321555,,260000", "shl 130"
count = count + 1
call assertEq Oct("430632,,155526")~shr(12)~string, "000043,,063215", "shr 130"
count = count + 1
call assertEq (Oct("430336,,371072") + Oct("116172,,323375"))~string, "546530,,714467", "add 131"
count = count + 1
call assertEq (Oct("430336,,371072") - Oct("116172,,323375"))~string, "312144,,045475", "sub 131"
count = count + 1
call assertEq (Oct("430336,,371072") & Oct("116172,,323375"))~string, "010132,,321070", "and 131"
count = count + 1
call assertEq (Oct("430336,,371072") | Oct("116172,,323375"))~string, "536376,,373377", "or 131"
count = count + 1
call assertEq (Oct("430336,,371072") && Oct("116172,,323375"))~string, "526244,,052307", "xor 131"
count = count + 1
call assertEq Oct("430336,,371072")~shl(40)~string, "000000,,000000", "shl 131"
count = count + 1
call assertEq Oct("430336,,371072")~shr(40)~string, "000000,,000000", "shr 131"
count = count + 1
call assertEq (Oct("245626,,315147") + Oct("502425,,103501"))~string, "750253,,420650", "add 132"
count = count + 1
call assertEq (Oct("245626,,315147") - Oct("502425,,103501"))~string, "543201,,211446", "sub 132"
count = count + 1
call assertEq (Oct("245626,,315147") & Oct("502425,,103501"))~string, "000424,,101101", "and 132"
count = count + 1
call assertEq (Oct("245626,,315147") | Oct("502425,,103501"))~string, "747627,,317547", "or 132"
count = count + 1
call assertEq (Oct("245626,,315147") && Oct("502425,,103501"))~string, "747203,,216446", "xor 132"
count = count + 1
call assertEq Oct("245626,,315147")~shl(17)~string, "146463,,400000", "shl 132"
count = count + 1
call assertEq Oct("245626,,315147")~shr(17)~string, "000000,,513454", "shr 132"
count = count + 1
call assertEq (Oct("324711,,367311") + Oct("242152,,313511"))~string, "567063,,703022", "add 133"
count = count + 1
call assertEq (Oct("324711,,367311") - Oct("242152,,313511"))~string, "062537,,053600", "sub 133"
count = count + 1
call assertEq (Oct("324711,,367311") & Oct("242152,,313511"))~string, "200110,,303111", "and 133"
count = count + 1
call assertEq (Oct("324711,,367311") | Oct("242152,,313511"))~string, "366753,,377711", "or 133"
count = count + 1
call assertEq (Oct("324711,,367311") && Oct("242152,,313511"))~string, "166643,,074600", "xor 133"
count = count + 1
call assertEq Oct("324711,,367311")~shl(33)~string, "100000,,000000", "shl 133"
count = count + 1
call assertEq Oct("324711,,367311")~shr(33)~string, "000000,,000003", "shr 133"
count = count + 1
call assertEq (Oct("017143,,716573") + Oct("136154,,046550"))~string, "155317,,765343", "add 134"
count = count + 1
call assertEq (Oct("017143,,716573") - Oct("136154,,046550"))~string, "660767,,650023", "sub 134"
count = count + 1
call assertEq (Oct("017143,,716573") & Oct("136154,,046550"))~string, "016140,,006550", "and 134"
count = count + 1
call assertEq (Oct("017143,,716573") | Oct("136154,,046550"))~string, "137157,,756573", "or 134"
count = count + 1
call assertEq (Oct("017143,,716573") && Oct("136154,,046550"))~string, "121017,,750023", "xor 134"
count = count + 1
call assertEq Oct("017143,,716573")~shl(9)~string, "143716,,573000", "shl 134"
count = count + 1
call assertEq Oct("017143,,716573")~shr(9)~string, "000017,,143716", "shr 134"
count = count + 1
call assertEq (Oct("130101,,360263") + Oct("023516,,470434"))~string, "153620,,050717", "add 135"
count = count + 1
call assertEq (Oct("130101,,360263") - Oct("023516,,470434"))~string, "104362,,667627", "sub 135"
count = count + 1
call assertEq (Oct("130101,,360263") & Oct("023516,,470434"))~string, "020100,,060020", "and 135"
count = count + 1
call assertEq (Oct("130101,,360263") | Oct("023516,,470434"))~string, "133517,,770677", "or 135"
count = count + 1
call assertEq (Oct("130101,,360263") && Oct("023516,,470434"))~string, "113417,,710657", "xor 135"
count = count + 1
call assertEq Oct("130101,,360263")~shl(16)~string, "274054,,600000", "shl 135"
count = count + 1
call assertEq Oct("130101,,360263")~shr(16)~string, "000000,,540405", "shr 135"
count = count + 1
call assertEq (Oct("215071,,473360") + Oct("661320,,005404"))~string, "076411,,500764", "add 136"
count = count + 1
call assertEq (Oct("215071,,473360") - Oct("661320,,005404"))~string, "333551,,465754", "sub 136"
count = count + 1
call assertEq (Oct("215071,,473360") & Oct("661320,,005404"))~string, "201020,,001000", "and 136"
count = count + 1
call assertEq (Oct("215071,,473360") | Oct("661320,,005404"))~string, "675371,,477764", "or 136"
count = count + 1
call assertEq (Oct("215071,,473360") && Oct("661320,,005404"))~string, "474351,,476764", "xor 136"
count = count + 1
call assertEq Oct("215071,,473360")~shl(31)~string, "400000,,000000", "shl 136"
count = count + 1
call assertEq Oct("215071,,473360")~shr(31)~string, "000000,,000010", "shr 136"
count = count + 1
call assertEq (Oct("217266,,121360") + Oct("174260,,057563"))~string, "413546,,201143", "add 137"
count = count + 1
call assertEq (Oct("217266,,121360") - Oct("174260,,057563"))~string, "023006,,041575", "sub 137"
count = count + 1
call assertEq (Oct("217266,,121360") & Oct("174260,,057563"))~string, "014260,,001160", "and 137"
count = count + 1
call assertEq (Oct("217266,,121360") | Oct("174260,,057563"))~string, "377266,,177763", "or 137"
count = count + 1
call assertEq (Oct("217266,,121360") && Oct("174260,,057563"))~string, "363006,,176603", "xor 137"
count = count + 1
call assertEq Oct("217266,,121360")~shl(39)~string, "000000,,000000", "shl 137"
count = count + 1
call assertEq Oct("217266,,121360")~shr(39)~string, "000000,,000000", "shr 137"
count = count + 1
call assertEq (Oct("136752,,557073") + Oct("706732,,344407"))~string, "045705,,123502", "add 138"
count = count + 1
call assertEq (Oct("136752,,557073") - Oct("706732,,344407"))~string, "230020,,212464", "sub 138"
count = count + 1
call assertEq (Oct("136752,,557073") & Oct("706732,,344407"))~string, "106712,,144003", "and 138"
count = count + 1
call assertEq (Oct("136752,,557073") | Oct("706732,,344407"))~string, "736772,,757477", "or 138"
count = count + 1
call assertEq (Oct("136752,,557073") && Oct("706732,,344407"))~string, "630060,,613474", "xor 138"
count = count + 1
call assertEq Oct("136752,,557073")~shl(1)~string, "275725,,336166", "shl 138"
count = count + 1
call assertEq Oct("136752,,557073")~shr(1)~string, "057365,,267435", "shr 138"
count = count + 1
call assertEq (Oct("355405,,105300") + Oct("474030,,552367"))~string, "051435,,657667", "add 139"
count = count + 1
call assertEq (Oct("355405,,105300") - Oct("474030,,552367"))~string, "661354,,332711", "sub 139"
count = count + 1
call assertEq (Oct("355405,,105300") & Oct("474030,,552367"))~string, "054000,,100300", "and 139"
count = count + 1
call assertEq (Oct("355405,,105300") | Oct("474030,,552367"))~string, "775435,,557367", "or 139"
count = count + 1
call assertEq (Oct("355405,,105300") && Oct("474030,,552367"))~string, "721435,,457067", "xor 139"
count = count + 1
call assertEq Oct("355405,,105300")~shl(8)~string, "602442,,540000", "shl 139"
count = count + 1
call assertEq Oct("355405,,105300")~shr(8)~string, "000733,,012212", "shr 139"
count = count + 1
call assertEq (Oct("143254,,377710") + Oct("353721,,465103"))~string, "517176,,065013", "add 140"
count = count + 1
call assertEq (Oct("143254,,377710") - Oct("353721,,465103"))~string, "567332,,712605", "sub 140"
count = count + 1
call assertEq (Oct("143254,,377710") & Oct("353721,,465103"))~string, "143200,,065100", "and 140"
count = count + 1
call assertEq (Oct("143254,,377710") | Oct("353721,,465103"))~string, "353775,,777713", "or 140"
count = count + 1
call assertEq (Oct("143254,,377710") && Oct("353721,,465103"))~string, "210575,,712613", "xor 140"
count = count + 1
call assertEq Oct("143254,,377710")~shl(36)~string, "000000,,000000", "shl 140"
count = count + 1
call assertEq Oct("143254,,377710")~shr(36)~string, "000000,,000000", "shr 140"
count = count + 1
call assertEq (Oct("054611,,533243") + Oct("462076,,226351"))~string, "536707,,761614", "add 141"
count = count + 1
call assertEq (Oct("054611,,533243") - Oct("462076,,226351"))~string, "372513,,304672", "sub 141"
count = count + 1
call assertEq (Oct("054611,,533243") & Oct("462076,,226351"))~string, "040010,,022241", "and 141"
count = count + 1
call assertEq (Oct("054611,,533243") | Oct("462076,,226351"))~string, "476677,,737353", "or 141"
count = count + 1
call assertEq (Oct("054611,,533243") && Oct("462076,,226351"))~string, "436667,,715112", "xor 141"
count = count + 1
call assertEq Oct("054611,,533243")~shl(4)~string, "314232,,665060", "shl 141"
count = count + 1
call assertEq Oct("054611,,533243")~shr(4)~string, "002630,,465552", "shr 141"
count = count + 1
call assertEq (Oct("003073,,451664") + Oct("077055,,745263"))~string, "102151,,417147", "add 142"
count = count + 1
call assertEq (Oct("003073,,451664") - Oct("077055,,745263"))~string, "704015,,504401", "sub 142"
count = count + 1
call assertEq (Oct("003073,,451664") & Oct("077055,,745263"))~string, "003051,,441260", "and 142"
count = count + 1
call assertEq (Oct("003073,,451664") | Oct("077055,,745263"))~string, "077077,,755667", "or 142"
count = count + 1
call assertEq (Oct("003073,,451664") && Oct("077055,,745263"))~string, "074026,,314407", "xor 142"
count = count + 1
call assertEq Oct("003073,,451664")~shl(8)~string, "435624,,732000", "shl 142"
count = count + 1
call assertEq Oct("003073,,451664")~shr(8)~string, "000006,,167123", "shr 142"
count = count + 1
call assertEq (Oct("706761,,557106") + Oct("254144,,666042"))~string, "163126,,445150", "add 143"
count = count + 1
call assertEq (Oct("706761,,557106") - Oct("254144,,666042"))~string, "432614,,671044", "sub 143"
count = count + 1
call assertEq (Oct("706761,,557106") & Oct("254144,,666042"))~string, "204140,,446002", "and 143"
count = count + 1
call assertEq (Oct("706761,,557106") | Oct("254144,,666042"))~string, "756765,,777146", "or 143"
count = count + 1
call assertEq (Oct("706761,,557106") && Oct("254144,,666042"))~string, "552625,,331144", "xor 143"
count = count + 1
call assertEq Oct("706761,,557106")~shl(1)~string, "615743,,336214", "shl 143"
count = count + 1
call assertEq Oct("706761,,557106")~shr(1)~string, "343370,,667443", "shr 143"
count = count + 1
call assertEq (Oct("240704,,427527") + Oct("345035,,023401"))~string, "605741,,453130", "add 144"
count = count + 1
call assertEq (Oct("240704,,427527") - Oct("345035,,023401"))~string, "673647,,404126", "sub 144"
count = count + 1
call assertEq (Oct("240704,,427527") & Oct("345035,,023401"))~string, "240004,,023401", "and 144"
count = count + 1
call assertEq (Oct("240704,,427527") | Oct("345035,,023401"))~string, "345735,,427527", "or 144"
count = count + 1
call assertEq (Oct("240704,,427527") && Oct("345035,,023401"))~string, "105731,,404126", "xor 144"
count = count + 1
call assertEq Oct("240704,,427527")~shl(30)~string, "270000,,000000", "shl 144"
count = count + 1
call assertEq Oct("240704,,427527")~shr(30)~string, "000000,,000024", "shr 144"
count = count + 1
call assertEq (Oct("461354,,164746") + Oct("462604,,026410"))~string, "144160,,213356", "add 145"
count = count + 1
call assertEq (Oct("461354,,164746") - Oct("462604,,026410"))~string, "776550,,136336", "sub 145"
count = count + 1
call assertEq (Oct("461354,,164746") & Oct("462604,,026410"))~string, "460204,,024400", "and 145"
count = count + 1
call assertEq (Oct("461354,,164746") | Oct("462604,,026410"))~string, "463754,,166756", "or 145"
count = count + 1
call assertEq (Oct("461354,,164746") && Oct("462604,,026410"))~string, "003550,,142356", "xor 145"
count = count + 1
call assertEq Oct("461354,,164746")~shl(11)~string, "660723,,630000", "shl 145"
count = count + 1
call assertEq Oct("461354,,164746")~shr(11)~string, "000114,,273035", "shr 145"
count = count + 1
call assertEq (Oct("645716,,041270") + Oct("750034,,651005"))~string, "615752,,712275", "add 146"
count = count + 1
call assertEq (Oct("645716,,041270") - Oct("750034,,651005"))~string, "675661,,170263", "sub 146"
count = count + 1
call assertEq (Oct("645716,,041270") & Oct("750034,,651005"))~string, "640014,,041000", "and 146"
count = count + 1
call assertEq (Oct("645716,,041270") | Oct("750034,,651005"))~string, "755736,,651275", "or 146"
count = count + 1
call assertEq (Oct("645716,,041270") && Oct("750034,,651005"))~string, "115722,,610275", "xor 146"
count = count + 1
call assertEq Oct("645716,,041270")~shl(11)~string, "470205,,340000", "shl 146"
count = count + 1
call assertEq Oct("645716,,041270")~shr(11)~string, "000151,,363410", "shr 146"
count = count + 1
call assertEq (Oct("416044,,067034") + Oct("221377,,324656"))~string, "637443,,413712", "add 147"
count = count + 1
call assertEq (Oct("416044,,067034") - Oct("221377,,324656"))~string, "174444,,542156", "sub 147"
count = count + 1
call assertEq (Oct("416044,,067034") & Oct("221377,,324656"))~string, "000044,,024014", "and 147"
count = count + 1
call assertEq (Oct("416044,,067034") | Oct("221377,,324656"))~string, "637377,,367676", "or 147"
count = count + 1
call assertEq (Oct("416044,,067034") && Oct("221377,,324656"))~string, "637333,,343662", "xor 147"
count = count + 1
call assertEq Oct("416044,,067034")~shl(4)~string, "341101,,560700", "shl 147"
count = count + 1
call assertEq Oct("416044,,067034")~shr(4)~string, "020702,,203341", "shr 147"
count = count + 1
call assertEq (Oct("300461,,643331") + Oct("716654,,327075"))~string, "217336,,172426", "add 148"
count = count + 1
call assertEq (Oct("300461,,643331") - Oct("716654,,327075"))~string, "361605,,314234", "sub 148"
count = count + 1
call assertEq (Oct("300461,,643331") & Oct("716654,,327075"))~string, "300440,,203031", "and 148"
count = count + 1
call assertEq (Oct("300461,,643331") | Oct("716654,,327075"))~string, "716675,,767375", "or 148"
count = count + 1
call assertEq (Oct("300461,,643331") && Oct("716654,,327075"))~string, "416235,,564344", "xor 148"
count = count + 1
call assertEq Oct("300461,,643331")~shl(30)~string, "310000,,000000", "shl 148"
count = count + 1
call assertEq Oct("300461,,643331")~shr(30)~string, "000000,,000030", "shr 148"
count = count + 1
call assertEq (Oct("271221,,403313") + Oct("052063,,136146"))~string, "343304,,541461", "add 149"
count = count + 1
call assertEq (Oct("271221,,403313") - Oct("052063,,136146"))~string, "217136,,245145", "sub 149"
count = count + 1
call assertEq (Oct("271221,,403313") & Oct("052063,,136146"))~string, "050021,,002102", "and 149"
count = count + 1
call assertEq (Oct("271221,,403313") | Oct("052063,,136146"))~string, "273263,,537357", "or 149"
count = count + 1
call assertEq (Oct("271221,,403313") && Oct("052063,,136146"))~string, "223242,,535255", "xor 149"
count = count + 1
call assertEq Oct("271221,,403313")~shl(31)~string, "260000,,000000", "shl 149"
count = count + 1
call assertEq Oct("271221,,403313")~shr(31)~string, "000000,,000013", "shr 149"
count = count + 1
call assertEq (Oct("763065,,243061") + Oct("536062,,140026"))~string, "521147,,403107", "add 150"
count = count + 1
call assertEq (Oct("763065,,243061") - Oct("536062,,140026"))~string, "225003,,103033", "sub 150"
count = count + 1
call assertEq (Oct("763065,,243061") & Oct("536062,,140026"))~string, "522060,,040020", "and 150"
count = count + 1
call assertEq (Oct("763065,,243061") | Oct("536062,,140026"))~string, "777067,,343067", "or 150"
count = count + 1
call assertEq (Oct("763065,,243061") && Oct("536062,,140026"))~string, "255007,,303047", "xor 150"
count = count + 1
call assertEq Oct("763065,,243061")~shl(28)~string, "142000,,000000", "shl 150"
count = count + 1
call assertEq Oct("763065,,243061")~shr(28)~string, "000000,,000371", "shr 150"
count = count + 1
call assertEq (Oct("533214,,435240") + Oct("752210,,110537"))~string, "505424,,545777", "add 151"
count = count + 1
call assertEq (Oct("533214,,435240") - Oct("752210,,110537"))~string, "561004,,324501", "sub 151"
count = count + 1
call assertEq (Oct("533214,,435240") & Oct("752210,,110537"))~string, "512210,,010000", "and 151"
count = count + 1
call assertEq (Oct("533214,,435240") | Oct("752210,,110537"))~string, "773214,,535777", "or 151"
count = count + 1
call assertEq (Oct("533214,,435240") && Oct("752210,,110537"))~string, "261004,,525777", "xor 151"
count = count + 1
call assertEq Oct("533214,,435240")~shl(2)~string, "555062,,165200", "shl 151"
count = count + 1
call assertEq Oct("533214,,435240")~shr(2)~string, "126643,,107250", "shr 151"
count = count + 1
call assertEq (Oct("352452,,413605") + Oct("401417,,602341"))~string, "754072,,216146", "add 152"
count = count + 1
call assertEq (Oct("352452,,413605") - Oct("401417,,602341"))~string, "751032,,611244", "sub 152"
count = count + 1
call assertEq (Oct("352452,,413605") & Oct("401417,,602341"))~string, "000412,,402201", "and 152"
count = count + 1
call assertEq (Oct("352452,,413605") | Oct("401417,,602341"))~string, "753457,,613745", "or 152"
count = count + 1
call assertEq (Oct("352452,,413605") && Oct("401417,,602341"))~string, "753045,,211544", "xor 152"
count = count + 1
call assertEq Oct("352452,,413605")~shl(15)~string, "241360,,500000", "shl 152"
count = count + 1
call assertEq Oct("352452,,413605")~shr(15)~string, "000003,,524524", "shr 152"
count = count + 1
call assertEq (Oct("075552,,113660") + Oct("220147,,245762"))~string, "315721,,361642", "add 153"
count = count + 1
call assertEq (Oct("075552,,113660") - Oct("220147,,245762"))~string, "655402,,645676", "sub 153"
count = count + 1
call assertEq (Oct("075552,,113660") & Oct("220147,,245762"))~string, "020142,,001660", "and 153"
count = count + 1
call assertEq (Oct("075552,,113660") | Oct("220147,,245762"))~string, "275557,,357762", "or 153"
count = count + 1
call assertEq (Oct("075552,,113660") && Oct("220147,,245762"))~string, "255415,,356102", "xor 153"
count = count + 1
call assertEq Oct("075552,,113660")~shl(38)~string, "000000,,000000", "shl 153"
count = count + 1
call assertEq Oct("075552,,113660")~shr(38)~string, "000000,,000000", "shr 153"
count = count + 1
call assertEq (Oct("034307,,362022") + Oct("360144,,576420"))~string, "414454,,160442", "add 154"
count = count + 1
call assertEq (Oct("034307,,362022") - Oct("360144,,576420"))~string, "454142,,563402", "sub 154"
count = count + 1
call assertEq (Oct("034307,,362022") & Oct("360144,,576420"))~string, "020104,,162020", "and 154"
count = count + 1
call assertEq (Oct("034307,,362022") | Oct("360144,,576420"))~string, "374347,,776422", "or 154"
count = count + 1
call assertEq (Oct("034307,,362022") && Oct("360144,,576420"))~string, "354243,,614402", "xor 154"
count = count + 1
call assertEq Oct("034307,,362022")~shl(24)~string, "202200,,000000", "shl 154"
count = count + 1
call assertEq Oct("034307,,362022")~shr(24)~string, "000000,,000343", "shr 154"
count = count + 1
call assertEq (Oct("022716,,630451") + Oct("627635,,304227"))~string, "652554,,134700", "add 155"
count = count + 1
call assertEq (Oct("022716,,630451") - Oct("627635,,304227"))~string, "173061,,324222", "sub 155"
count = count + 1
call assertEq (Oct("022716,,630451") & Oct("627635,,304227"))~string, "022614,,200001", "and 155"
count = count + 1
call assertEq (Oct("022716,,630451") | Oct("627635,,304227"))~string, "627737,,734677", "or 155"
count = count + 1
call assertEq (Oct("022716,,630451") && Oct("627635,,304227"))~string, "605123,,534676", "xor 155"
count = count + 1
call assertEq Oct("022716,,630451")~shl(3)~string, "227166,,304510", "shl 155"
count = count + 1
call assertEq Oct("022716,,630451")~shr(3)~string, "002271,,663045", "shr 155"
count = count + 1
call assertEq (Oct("756336,,063015") + Oct("337611,,057522"))~string, "316147,,142537", "add 156"
count = count + 1
call assertEq (Oct("756336,,063015") - Oct("337611,,057522"))~string, "416525,,003273", "sub 156"
count = count + 1
call assertEq (Oct("756336,,063015") & Oct("337611,,057522"))~string, "316210,,043000", "and 156"
count = count + 1
call assertEq (Oct("756336,,063015") | Oct("337611,,057522"))~string, "777737,,077537", "or 156"
count = count + 1
call assertEq (Oct("756336,,063015") && Oct("337611,,057522"))~string, "461527,,034537", "xor 156"
count = count + 1
call assertEq Oct("756336,,063015")~shl(14)~string, "703140,,640000", "shl 156"
count = count + 1
call assertEq Oct("756336,,063015")~shr(14)~string, "000017,,346741", "shr 156"
count = count + 1
call assertEq (Oct("755257,,602016") + Oct("251022,,041332"))~string, "226301,,643350", "add 157"
count = count + 1
call assertEq (Oct("755257,,602016") - Oct("251022,,041332"))~string, "504235,,540464", "sub 157"
count = count + 1
call assertEq (Oct("755257,,602016") & Oct("251022,,041332"))~string, "251002,,000012", "and 157"
count = count + 1
call assertEq (Oct("755257,,602016") | Oct("251022,,041332"))~string, "755277,,643336", "or 157"
count = count + 1
call assertEq (Oct("755257,,602016") && Oct("251022,,041332"))~string, "504275,,643324", "xor 157"
count = count + 1
call assertEq Oct("755257,,602016")~shl(22)~string, "040340,,000000", "shl 157"
count = count + 1
call assertEq Oct("755257,,602016")~shr(22)~string, "000000,,036652", "shr 157"
count = count + 1
call assertEq (Oct("134064,,253574") + Oct("461263,,524456"))~string, "615350,,000252", "add 158"
count = count + 1
call assertEq (Oct("134064,,253574") - Oct("461263,,524456"))~string, "452600,,527116", "sub 158"
count = count + 1
call assertEq (Oct("134064,,253574") & Oct("461263,,524456"))~string, "020060,,000454", "and 158"
count = count + 1
call assertEq (Oct("134064,,253574") | Oct("461263,,524456"))~string, "575267,,777576", "or 158"
count = count + 1
call assertEq (Oct("134064,,253574") && Oct("461263,,524456"))~string, "555207,,777122", "xor 158"
count = count + 1
call assertEq Oct("134064,,253574")~shl(4)~string, "701505,,273700", "shl 158"
count = count + 1
call assertEq Oct("134064,,253574")~shr(4)~string, "005603,,212567", "shr 158"
count = count + 1
call assertEq (Oct("032371,,620032") + Oct("112330,,752507"))~string, "144722,,572541", "add 159"
count = count + 1
call assertEq (Oct("032371,,620032") - Oct("112330,,752507"))~string, "720040,,645323", "sub 159"
count = count + 1
call assertEq (Oct("032371,,620032") & Oct("112330,,752507"))~string, "012330,,600002", "and 159"
count = count + 1
call assertEq (Oct("032371,,620032") | Oct("112330,,752507"))~string, "132371,,772537", "or 159"
count = count + 1
call assertEq (Oct("032371,,620032") && Oct("112330,,752507"))~string, "120041,,172535", "xor 159"
count = count + 1
call assertEq Oct("032371,,620032")~shl(35)~string, "000000,,000000", "shl 159"
count = count + 1
call assertEq Oct("032371,,620032")~shr(35)~string, "000000,,000000", "shr 159"
count = count + 1
call assertEq (Oct("434216,,461103") + Oct("563716,,761573"))~string, "220135,,442676", "add 160"
count = count + 1
call assertEq (Oct("434216,,461103") - Oct("563716,,761573"))~string, "650277,,477310", "sub 160"
count = count + 1
call assertEq (Oct("434216,,461103") & Oct("563716,,761573"))~string, "420216,,461103", "and 160"
count = count + 1
call assertEq (Oct("434216,,461103") | Oct("563716,,761573"))~string, "577716,,761573", "or 160"
count = count + 1
call assertEq (Oct("434216,,461103") && Oct("563716,,761573"))~string, "157500,,300470", "xor 160"
count = count + 1
call assertEq Oct("434216,,461103")~shl(29)~string, "414000,,000000", "shl 160"
count = count + 1
call assertEq Oct("434216,,461103")~shr(29)~string, "000000,,000107", "shr 160"
count = count + 1
call assertEq (Oct("257222,,253126") + Oct("472650,,331145"))~string, "752072,,604273", "add 161"
count = count + 1
call assertEq (Oct("257222,,253126") - Oct("472650,,331145"))~string, "564351,,721761", "sub 161"
count = count + 1
call assertEq (Oct("257222,,253126") & Oct("472650,,331145"))~string, "052200,,211104", "and 161"
count = count + 1
call assertEq (Oct("257222,,253126") | Oct("472650,,331145"))~string, "677672,,373167", "or 161"
count = count + 1
call assertEq (Oct("257222,,253126") && Oct("472650,,331145"))~string, "625472,,162063", "xor 161"
count = count + 1
call assertEq Oct("257222,,253126")~shl(34)~string, "400000,,000000", "shl 161"
count = count + 1
call assertEq Oct("257222,,253126")~shr(34)~string, "000000,,000001", "shr 161"
count = count + 1
call assertEq (Oct("562227,,113230") + Oct("306253,,104765"))~string, "070502,,220215", "add 162"
count = count + 1
call assertEq (Oct("562227,,113230") - Oct("306253,,104765"))~string, "253754,,006243", "sub 162"
count = count + 1
call assertEq (Oct("562227,,113230") & Oct("306253,,104765"))~string, "102203,,100220", "and 162"
count = count + 1
call assertEq (Oct("562227,,113230") | Oct("306253,,104765"))~string, "766277,,117775", "or 162"
count = count + 1
call assertEq (Oct("562227,,113230") && Oct("306253,,104765"))~string, "664074,,017555", "xor 162"
count = count + 1
call assertEq Oct("562227,,113230")~shl(19)~string, "226460,,000000", "shl 162"
count = count + 1
call assertEq Oct("562227,,113230")~shr(19)~string, "000000,,271113", "shr 162"
count = count + 1
call assertEq (Oct("303236,,130164") + Oct("057713,,512005"))~string, "363151,,642171", "add 163"
count = count + 1
call assertEq (Oct("303236,,130164") - Oct("057713,,512005"))~string, "223322,,416157", "sub 163"
count = count + 1
call assertEq (Oct("303236,,130164") & Oct("057713,,512005"))~string, "003212,,110004", "and 163"
count = count + 1
call assertEq (Oct("303236,,130164") | Oct("057713,,512005"))~string, "357737,,532165", "or 163"
count = count + 1
call assertEq (Oct("303236,,130164") && Oct("057713,,512005"))~string, "354525,,422161", "xor 163"
count = count + 1
call assertEq Oct("303236,,130164")~shl(23)~string, "407200,,000000", "shl 163"
count = count + 1
call assertEq Oct("303236,,130164")~shr(23)~string, "000000,,006064", "shr 163"
count = count + 1
call assertEq (Oct("112141,,364320") + Oct("763530,,477720"))~string, "075672,,064240", "add 164"
count = count + 1
call assertEq (Oct("112141,,364320") - Oct("763530,,477720"))~string, "126410,,664400", "sub 164"
count = count + 1
call assertEq (Oct("112141,,364320") & Oct("763530,,477720"))~string, "102100,,064320", "and 164"
count = count + 1
call assertEq (Oct("112141,,364320") | Oct("763530,,477720"))~string, "773571,,777720", "or 164"
count = count + 1
call assertEq (Oct("112141,,364320") && Oct("763530,,477720"))~string, "671471,,713400", "xor 164"
count = count + 1
call assertEq Oct("112141,,364320")~shl(18)~string, "364320,,000000", "shl 164"
count = count + 1
call assertEq Oct("112141,,364320")~shr(18)~string, "000000,,112141", "shr 164"
count = count + 1
call assertEq (Oct("745422,,152513") + Oct("062327,,670670"))~string, "027752,,043403", "add 165"
count = count + 1
call assertEq (Oct("745422,,152513") - Oct("062327,,670670"))~string, "663072,,261623", "sub 165"
count = count + 1
call assertEq (Oct("745422,,152513") & Oct("062327,,670670"))~string, "040022,,050410", "and 165"
count = count + 1
call assertEq (Oct("745422,,152513") | Oct("062327,,670670"))~string, "767727,,772773", "or 165"
count = count + 1
call assertEq (Oct("745422,,152513") && Oct("062327,,670670"))~string, "727705,,722363", "xor 165"
count = count + 1
call assertEq Oct("745422,,152513")~shl(13)~string, "443252,,260000", "shl 165"
count = count + 1
call assertEq Oct("745422,,152513")~shr(13)~string, "000036,,261106", "shr 165"
count = count + 1
call assertEq (Oct("450125,,331246") + Oct("236711,,461551"))~string, "707037,,013017", "add 166"
count = count + 1
call assertEq (Oct("450125,,331246") - Oct("236711,,461551"))~string, "211213,,647475", "sub 166"
count = count + 1
call assertEq (Oct("450125,,331246") & Oct("236711,,461551"))~string, "010101,,021040", "and 166"
count = count + 1
call assertEq (Oct("450125,,331246") | Oct("236711,,461551"))~string, "676735,,771757", "or 166"
count = count + 1
call assertEq (Oct("450125,,331246") && Oct("236711,,461551"))~string, "666634,,750717", "xor 166"
count = count + 1
call assertEq Oct("450125,,331246")~shl(23)~string, "452300,,000000", "shl 166"
count = count + 1
call assertEq Oct("450125,,331246")~shr(23)~string, "000000,,011202", "shr 166"
count = count + 1
call assertEq (Oct("244065,,100612") + Oct("575202,,133662"))~string, "041267,,234474", "add 167"
count = count + 1
call assertEq (Oct("244065,,100612") - Oct("575202,,133662"))~string, "446662,,744730", "sub 167"
count = count + 1
call assertEq (Oct("244065,,100612") & Oct("575202,,133662"))~string, "044000,,100602", "and 167"
count = count + 1
call assertEq (Oct("244065,,100612") | Oct("575202,,133662"))~string, "775267,,133672", "or 167"
count = count + 1
call assertEq (Oct("244065,,100612") && Oct("575202,,133662"))~string, "731267,,033070", "xor 167"
count = count + 1
call assertEq Oct("244065,,100612")~shl(7)~string, "015220,,142400", "shl 167"
count = count + 1
call assertEq Oct("244065,,100612")~shr(7)~string, "001220,,324403", "shr 167"
count = count + 1
call assertEq (Oct("647764,,562313") + Oct("215755,,732714"))~string, "065742,,515227", "add 168"
count = count + 1
call assertEq (Oct("647764,,562313") - Oct("215755,,732714"))~string, "432006,,627377", "sub 168"
count = count + 1
call assertEq (Oct("647764,,562313") & Oct("215755,,732714"))~string, "205744,,522310", "and 168"
count = count + 1
call assertEq (Oct("647764,,562313") | Oct("215755,,732714"))~string, "657775,,772717", "or 168"
count = count + 1
call assertEq (Oct("647764,,562313") && Oct("215755,,732714"))~string, "452031,,250407", "xor 168"
count = count + 1
call assertEq Oct("647764,,562313")~shl(2)~string, "237722,,711454", "shl 168"
count = count + 1
call assertEq Oct("647764,,562313")~shr(2)~string, "151775,,134462", "shr 168"
count = count + 1
call assertEq (Oct("650242,,632465") + Oct("657775,,023175"))~string, "530237,,655662", "add 169"
count = count + 1
call assertEq (Oct("650242,,632465") - Oct("657775,,023175"))~string, "770245,,607270", "sub 169"
count = count + 1
call assertEq (Oct("650242,,632465") & Oct("657775,,023175"))~string, "650240,,022065", "and 169"
count = count + 1
call assertEq (Oct("650242,,632465") | Oct("657775,,023175"))~string, "657777,,633575", "or 169"
count = count + 1
call assertEq (Oct("650242,,632465") && Oct("657775,,023175"))~string, "007537,,611510", "xor 169"
count = count + 1
call assertEq Oct("650242,,632465")~shl(22)~string, "651520,,000000", "shl 169"
count = count + 1
call assertEq Oct("650242,,632465")~shr(22)~string, "000000,,032412", "shr 169"
count = count + 1
call assertEq (Oct("735504,,131136") + Oct("675477,,427410"))~string, "633203,,560546", "add 170"
count = count + 1
call assertEq (Oct("735504,,131136") - Oct("675477,,427410"))~string, "040004,,501526", "sub 170"
count = count + 1
call assertEq (Oct("735504,,131136") & Oct("675477,,427410"))~string, "635404,,021010", "and 170"
count = count + 1
call assertEq (Oct("735504,,131136") | Oct("675477,,427410"))~string, "775577,,537536", "or 170"
count = count + 1
call assertEq (Oct("735504,,131136") && Oct("675477,,427410"))~string, "140173,,516526", "xor 170"
count = count + 1
call assertEq Oct("735504,,131136")~shl(2)~string, "566420,,544570", "shl 170"
count = count + 1
call assertEq Oct("735504,,131136")~shr(2)~string, "167321,,026227", "shr 170"
count = count + 1
call assertEq (Oct("016266,,654563") + Oct("166413,,720574"))~string, "204702,,575357", "add 171"
count = count + 1
call assertEq (Oct("016266,,654563") - Oct("166413,,720574"))~string, "627652,,733767", "sub 171"
count = count + 1
call assertEq (Oct("016266,,654563") & Oct("166413,,720574"))~string, "006002,,600560", "and 171"
count = count + 1
call assertEq (Oct("016266,,654563") | Oct("166413,,720574"))~string, "176677,,774577", "or 171"
count = count + 1
call assertEq (Oct("016266,,654563") && Oct("166413,,720574"))~string, "170675,,174017", "xor 171"
count = count + 1
call assertEq Oct("016266,,654563")~shl(14)~string, "332627,,140000", "shl 171"
count = count + 1
call assertEq Oct("016266,,654563")~shr(14)~string, "000000,,345555", "shr 171"
count = count + 1
call assertEq (Oct("032617,,063552") + Oct("706172,,120315"))~string, "741011,,204067", "add 172"
count = count + 1
call assertEq (Oct("032617,,063552") - Oct("706172,,120315"))~string, "124424,,743235", "sub 172"
count = count + 1
call assertEq (Oct("032617,,063552") & Oct("706172,,120315"))~string, "002012,,020110", "and 172"
count = count + 1
call assertEq (Oct("032617,,063552") | Oct("706172,,120315"))~string, "736777,,163757", "or 172"
count = count + 1
call assertEq (Oct("032617,,063552") && Oct("706172,,120315"))~string, "734765,,143647", "xor 172"
count = count + 1
call assertEq Oct("032617,,063552")~shl(22)~string, "473240,,000000", "shl 172"
count = count + 1
call assertEq Oct("032617,,063552")~shr(22)~string, "000000,,001530", "shr 172"
count = count + 1
call assertEq (Oct("125225,,220613") + Oct("207746,,324017"))~string, "335173,,544632", "add 173"
count = count + 1
call assertEq (Oct("125225,,220613") - Oct("207746,,324017"))~string, "715256,,674574", "sub 173"
count = count + 1
call assertEq (Oct("125225,,220613") & Oct("207746,,324017"))~string, "005204,,220013", "and 173"
count = count + 1
call assertEq (Oct("125225,,220613") | Oct("207746,,324017"))~string, "327767,,324617", "or 173"
count = count + 1
call assertEq (Oct("125225,,220613") && Oct("207746,,324017"))~string, "322563,,104604", "xor 173"
count = count + 1
call assertEq Oct("125225,,220613")~shl(24)~string, "061300,,000000", "shl 173"
count = count + 1
call assertEq Oct("125225,,220613")~shr(24)~string, "000000,,001252", "shr 173"
count = count + 1
call assertEq (Oct("066211,,754343") + Oct("175665,,770715"))~string, "264077,,745260", "add 174"
count = count + 1
call assertEq (Oct("066211,,754343") - Oct("175665,,770715"))~string, "670323,,763426", "sub 174"
count = count + 1
call assertEq (Oct("066211,,754343") & Oct("175665,,770715"))~string, "064201,,750301", "and 174"
count = count + 1
call assertEq (Oct("066211,,754343") | Oct("175665,,770715"))~string, "177675,,774757", "or 174"
count = count + 1
call assertEq (Oct("066211,,754343") && Oct("175665,,770715"))~string, "113474,,024456", "xor 174"
count = count + 1
call assertEq Oct("066211,,754343")~shl(16)~string, "373070,,600000", "shl 174"
count = count + 1
call assertEq Oct("066211,,754343")~shr(16)~string, "000000,,331047", "shr 174"
count = count + 1
call assertEq (Oct("032246,,544266") + Oct("525533,,741224"))~string, "560002,,505512", "add 175"
count = count + 1
call assertEq (Oct("032246,,544266") - Oct("525533,,741224"))~string, "304512,,603042", "sub 175"
count = count + 1
call assertEq (Oct("032246,,544266") & Oct("525533,,741224"))~string, "020002,,540224", "and 175"
count = count + 1
call assertEq (Oct("032246,,544266") | Oct("525533,,741224"))~string, "537777,,745266", "or 175"
count = count + 1
call assertEq (Oct("032246,,544266") && Oct("525533,,741224"))~string, "517775,,205042", "xor 175"
count = count + 1
call assertEq Oct("032246,,544266")~shl(13)~string, "153105,,540000", "shl 175"
count = count + 1
call assertEq Oct("032246,,544266")~shr(13)~string, "000001,,512326", "shr 175"
count = count + 1
call assertEq (Oct("522100,,416207") + Oct("544620,,657003"))~string, "266721,,275212", "add 176"
count = count + 1
call assertEq (Oct("522100,,416207") - Oct("544620,,657003"))~string, "755257,,537204", "sub 176"
count = count + 1
call assertEq (Oct("522100,,416207") & Oct("544620,,657003"))~string, "500000,,416003", "and 176"
count = count + 1
call assertEq (Oct("522100,,416207") | Oct("544620,,657003"))~string, "566720,,657207", "or 176"
count = count + 1
call assertEq (Oct("522100,,416207") && Oct("544620,,657003"))~string, "066720,,241204", "xor 176"
count = count + 1
call assertEq Oct("522100,,416207")~shl(36)~string, "000000,,000000", "shl 176"
count = count + 1
call assertEq Oct("522100,,416207")~shr(36)~string, "000000,,000000", "shr 176"
count = count + 1
call assertEq (Oct("560351,,432550") + Oct("324020,,544755"))~string, "104372,,177525", "add 177"
count = count + 1
call assertEq (Oct("560351,,432550") - Oct("324020,,544755"))~string, "234330,,665573", "sub 177"
count = count + 1
call assertEq (Oct("560351,,432550") & Oct("324020,,544755"))~string, "120000,,400550", "and 177"
count = count + 1
call assertEq (Oct("560351,,432550") | Oct("324020,,544755"))~string, "764371,,576755", "or 177"
count = count + 1
call assertEq (Oct("560351,,432550") && Oct("324020,,544755"))~string, "644371,,176205", "xor 177"
count = count + 1
call assertEq Oct("560351,,432550")~shl(13)~string, "230653,,200000", "shl 177"
count = count + 1
call assertEq Oct("560351,,432550")~shr(13)~string, "000027,,016461", "shr 177"
count = count + 1
call assertEq (Oct("042734,,416300") + Oct("274006,,472115"))~string, "336743,,110415", "add 178"
count = count + 1
call assertEq (Oct("042734,,416300") - Oct("274006,,472115"))~string, "546725,,724163", "sub 178"
count = count + 1
call assertEq (Oct("042734,,416300") & Oct("274006,,472115"))~string, "040004,,412100", "and 178"
count = count + 1
call assertEq (Oct("042734,,416300") | Oct("274006,,472115"))~string, "276736,,476315", "or 178"
count = count + 1
call assertEq (Oct("042734,,416300") && Oct("274006,,472115"))~string, "236732,,064215", "xor 178"
count = count + 1
call assertEq Oct("042734,,416300")~shl(21)~string, "163000,,000000", "shl 178"
count = count + 1
call assertEq Oct("042734,,416300")~shr(21)~string, "000000,,004273", "shr 178"
count = count + 1
call assertEq (Oct("102133,,055075") + Oct("774323,,051301"))~string, "076456,,126376", "add 179"
count = count + 1
call assertEq (Oct("102133,,055075") - Oct("774323,,051301"))~string, "105610,,003574", "sub 179"
count = count + 1
call assertEq (Oct("102133,,055075") & Oct("774323,,051301"))~string, "100123,,051001", "and 179"
count = count + 1
call assertEq (Oct("102133,,055075") | Oct("774323,,051301"))~string, "776333,,055375", "or 179"
count = count + 1
call assertEq (Oct("102133,,055075") && Oct("774323,,051301"))~string, "676210,,004374", "xor 179"
count = count + 1
call assertEq Oct("102133,,055075")~shl(7)~string, "426613,,217200", "shl 179"
count = count + 1
call assertEq Oct("102133,,055075")~shr(7)~string, "000410,,554264", "shr 179"
count = count + 1
call assertEq (Oct("034230,,371333") + Oct("222730,,656741"))~string, "257161,,250274", "add 180"
count = count + 1
call assertEq (Oct("034230,,371333") - Oct("222730,,656741"))~string, "611277,,512372", "sub 180"
count = count + 1
call assertEq (Oct("034230,,371333") & Oct("222730,,656741"))~string, "020230,,250301", "and 180"
count = count + 1
call assertEq (Oct("034230,,371333") | Oct("222730,,656741"))~string, "236730,,777773", "or 180"
count = count + 1
call assertEq (Oct("034230,,371333") && Oct("222730,,656741"))~string, "216500,,527472", "xor 180"
count = count + 1
call assertEq Oct("034230,,371333")~shl(13)~string, "607626,,660000", "shl 180"
count = count + 1
call assertEq Oct("034230,,371333")~shr(13)~string, "000001,,611417", "shr 180"
count = count + 1
call assertEq (Oct("014556,,533463") + Oct("134653,,471231"))~string, "151432,,224714", "add 181"
count = count + 1
call assertEq (Oct("014556,,533463") - Oct("134653,,471231"))~string, "657703,,042232", "sub 181"
count = count + 1
call assertEq (Oct("014556,,533463") & Oct("134653,,471231"))~string, "014452,,431021", "and 181"
count = count + 1
call assertEq (Oct("014556,,533463") | Oct("134653,,471231"))~string, "134757,,573673", "or 181"
count = count + 1
call assertEq (Oct("014556,,533463") && Oct("134653,,471231"))~string, "120305,,142652", "xor 181"
count = count + 1
call assertEq Oct("014556,,533463")~shl(32)~string, "140000,,000000", "shl 181"
count = count + 1
call assertEq Oct("014556,,533463")~shr(32)~string, "000000,,000000", "shr 181"
count = count + 1
call assertEq (Oct("471264,,216744") + Oct("220632,,064622"))~string, "712116,,303566", "add 182"
count = count + 1
call assertEq (Oct("471264,,216744") - Oct("220632,,064622"))~string, "250432,,132122", "sub 182"
count = count + 1
call assertEq (Oct("471264,,216744") & Oct("220632,,064622"))~string, "020220,,004600", "and 182"
count = count + 1
call assertEq (Oct("471264,,216744") | Oct("220632,,064622"))~string, "671676,,276766", "or 182"
count = count + 1
call assertEq (Oct("471264,,216744") && Oct("220632,,064622"))~string, "651456,,272166", "xor 182"
count = count + 1
call assertEq Oct("471264,,216744")~shl(10)~string, "550435,,710000", "shl 182"
count = count + 1
call assertEq Oct("471264,,216744")~shr(10)~string, "000234,,532107", "shr 182"
count = count + 1
call assertEq (Oct("240251,,576222") + Oct("225030,,112022"))~string, "465301,,710244", "add 183"
count = count + 1
call assertEq (Oct("240251,,576222") - Oct("225030,,112022"))~string, "013221,,464200", "sub 183"
count = count + 1
call assertEq (Oct("240251,,576222") & Oct("225030,,112022"))~string, "200010,,112022", "and 183"
count = count + 1
call assertEq (Oct("240251,,576222") | Oct("225030,,112022"))~string, "265271,,576222", "or 183"
count = count + 1
call assertEq (Oct("240251,,576222") && Oct("225030,,112022"))~string, "065261,,464200", "xor 183"
count = count + 1
call assertEq Oct("240251,,576222")~shl(31)~string, "440000,,000000", "shl 183"
count = count + 1
call assertEq Oct("240251,,576222")~shr(31)~string, "000000,,000012", "shr 183"
count = count + 1
call assertEq (Oct("641754,,017706") + Oct("707670,,362367"))~string, "551644,,402275", "add 184"
count = count + 1
call assertEq (Oct("641754,,017706") - Oct("707670,,362367"))~string, "732063,,435317", "sub 184"
count = count + 1
call assertEq (Oct("641754,,017706") & Oct("707670,,362367"))~string, "601650,,002306", "and 184"
count = count + 1
call assertEq (Oct("641754,,017706") | Oct("707670,,362367"))~string, "747774,,377767", "or 184"
count = count + 1
call assertEq (Oct("641754,,017706") && Oct("707670,,362367"))~string, "146124,,375461", "xor 184"
count = count + 1
call assertEq Oct("641754,,017706")~shl(39)~string, "000000,,000000", "shl 184"
count = count + 1
call assertEq Oct("641754,,017706")~shr(39)~string, "000000,,000000", "shr 184"
count = count + 1
call assertEq (Oct("646341,,324342") + Oct("355661,,475443"))~string, "224223,,022005", "add 185"
count = count + 1
call assertEq (Oct("646341,,324342") - Oct("355661,,475443"))~string, "270457,,626677", "sub 185"
count = count + 1
call assertEq (Oct("646341,,324342") & Oct("355661,,475443"))~string, "244241,,024042", "and 185"
count = count + 1
call assertEq (Oct("646341,,324342") | Oct("355661,,475443"))~string, "757761,,775743", "or 185"
count = count + 1
call assertEq (Oct("646341,,324342") && Oct("355661,,475443"))~string, "513520,,751701", "xor 185"
count = count + 1
call assertEq Oct("646341,,324342")~shl(7)~string, "470265,,070400", "shl 185"
count = count + 1
call assertEq Oct("646341,,324342")~shr(7)~string, "003231,,605521", "shr 185"
count = count + 1
call assertEq (Oct("367470,,015664") + Oct("756251,,123475"))~string, "345741,,141361", "add 186"
count = count + 1
call assertEq (Oct("367470,,015664") - Oct("756251,,123475"))~string, "411216,,672167", "sub 186"
count = count + 1
call assertEq (Oct("367470,,015664") & Oct("756251,,123475"))~string, "346050,,001464", "and 186"
count = count + 1
call assertEq (Oct("367470,,015664") | Oct("756251,,123475"))~string, "777671,,137675", "or 186"
count = count + 1
call assertEq (Oct("367470,,015664") && Oct("756251,,123475"))~string, "431621,,136211", "xor 186"
count = count + 1
call assertEq Oct("367470,,015664")~shl(3)~string, "674700,,156640", "shl 186"
count = count + 1
call assertEq Oct("367470,,015664")~shr(3)~string, "036747,,001566", "shr 186"
count = count + 1
call assertEq (Oct("630002,,657113") + Oct("144521,,265166"))~string, "774524,,144301", "add 187"
count = count + 1
call assertEq (Oct("630002,,657113") - Oct("144521,,265166"))~string, "463261,,371725", "sub 187"
count = count + 1
call assertEq (Oct("630002,,657113") & Oct("144521,,265166"))~string, "000000,,245102", "and 187"
count = count + 1
call assertEq (Oct("630002,,657113") | Oct("144521,,265166"))~string, "774523,,677177", "or 187"
count = count + 1
call assertEq (Oct("630002,,657113") && Oct("144521,,265166"))~string, "774523,,432075", "xor 187"
count = count + 1
call assertEq Oct("630002,,657113")~shl(18)~string, "657113,,000000", "shl 187"
count = count + 1
call assertEq Oct("630002,,657113")~shr(18)~string, "000000,,630002", "shr 187"
count = count + 1
call assertEq (Oct("353754,,237354") + Oct("612464,,535430"))~string, "166440,,775004", "add 188"
count = count + 1
call assertEq (Oct("353754,,237354") - Oct("612464,,535430"))~string, "541267,,501724", "sub 188"
count = count + 1
call assertEq (Oct("353754,,237354") & Oct("612464,,535430"))~string, "212444,,035010", "and 188"
count = count + 1
call assertEq (Oct("353754,,237354") | Oct("612464,,535430"))~string, "753774,,737774", "or 188"
count = count + 1
call assertEq (Oct("353754,,237354") && Oct("612464,,535430"))~string, "541330,,702764", "xor 188"
count = count + 1
call assertEq Oct("353754,,237354")~shl(10)~string, "730476,,730000", "shl 188"
count = count + 1
call assertEq Oct("353754,,237354")~shr(10)~string, "000165,,766117", "shr 188"
count = count + 1
call assertEq (Oct("575576,,231761") + Oct("705144,,376402"))~string, "502742,,630363", "add 189"
count = count + 1
call assertEq (Oct("575576,,231761") - Oct("705144,,376402"))~string, "670431,,633357", "sub 189"
count = count + 1
call assertEq (Oct("575576,,231761") & Oct("705144,,376402"))~string, "505144,,230400", "and 189"
count = count + 1
call assertEq (Oct("575576,,231761") | Oct("705144,,376402"))~string, "775576,,377763", "or 189"
count = count + 1
call assertEq (Oct("575576,,231761") && Oct("705144,,376402"))~string, "270432,,147363", "xor 189"
count = count + 1
call assertEq Oct("575576,,231761")~shl(32)~string, "040000,,000000", "shl 189"
count = count + 1
call assertEq Oct("575576,,231761")~shr(32)~string, "000000,,000013", "shr 189"
count = count + 1
call assertEq (Oct("203316,,314542") + Oct("645574,,102664"))~string, "051112,,417426", "add 190"
count = count + 1
call assertEq (Oct("203316,,314542") - Oct("645574,,102664"))~string, "335522,,211656", "sub 190"
count = count + 1
call assertEq (Oct("203316,,314542") & Oct("645574,,102664"))~string, "201114,,100440", "and 190"
count = count + 1
call assertEq (Oct("203316,,314542") | Oct("645574,,102664"))~string, "647776,,316766", "or 190"
count = count + 1
call assertEq (Oct("203316,,314542") && Oct("645574,,102664"))~string, "446662,,216326", "xor 190"
count = count + 1
call assertEq Oct("203316,,314542")~shl(8)~string, "547146,,261000", "shl 190"
count = count + 1
call assertEq Oct("203316,,314542")~shr(8)~string, "000406,,634631", "shr 190"
count = count + 1
call assertEq (Oct("570401,,113644") + Oct("176374,,023067"))~string, "766775,,136733", "add 191"
count = count + 1
call assertEq (Oct("570401,,113644") - Oct("176374,,023067"))~string, "372005,,070555", "sub 191"
count = count + 1
call assertEq (Oct("570401,,113644") & Oct("176374,,023067"))~string, "170000,,003044", "and 191"
count = count + 1
call assertEq (Oct("570401,,113644") | Oct("176374,,023067"))~string, "576775,,133667", "or 191"
count = count + 1
call assertEq (Oct("570401,,113644") && Oct("176374,,023067"))~string, "406775,,130623", "xor 191"
count = count + 1
call assertEq Oct("570401,,113644")~shl(26)~string, "722000,,000000", "shl 191"
count = count + 1
call assertEq Oct("570401,,113644")~shr(26)~string, "000000,,001361", "shr 191"
count = count + 1
call assertEq (Oct("616724,,575635") + Oct("136476,,743550"))~string, "755423,,541405", "add 192"
count = count + 1
call assertEq (Oct("616724,,575635") - Oct("136476,,743550"))~string, "460225,,632065", "sub 192"
count = count + 1
call assertEq (Oct("616724,,575635") & Oct("136476,,743550"))~string, "016424,,541410", "and 192"
count = count + 1
call assertEq (Oct("616724,,575635") | Oct("136476,,743550"))~string, "736776,,777775", "or 192"
count = count + 1
call assertEq (Oct("616724,,575635") && Oct("136476,,743550"))~string, "720352,,236365", "xor 192"
count = count + 1
call assertEq Oct("616724,,575635")~shl(14)~string, "227671,,640000", "shl 192"
count = count + 1
call assertEq Oct("616724,,575635")~shr(14)~string, "000014,,356513", "shr 192"
count = count + 1
call assertEq (Oct("054752,,744452") + Oct("424701,,341726"))~string, "501654,,306400", "add 193"
count = count + 1
call assertEq (Oct("054752,,744452") - Oct("424701,,341726"))~string, "430051,,402524", "sub 193"
count = count + 1
call assertEq (Oct("054752,,744452") & Oct("424701,,341726"))~string, "004700,,340402", "and 193"
count = count + 1
call assertEq (Oct("054752,,744452") | Oct("424701,,341726"))~string, "474753,,745776", "or 193"
count = count + 1
call assertEq (Oct("054752,,744452") && Oct("424701,,341726"))~string, "470053,,405374", "xor 193"
count = count + 1
call assertEq Oct("054752,,744452")~shl(0)~string, "054752,,744452", "shl 193"
count = count + 1
call assertEq Oct("054752,,744452")~shr(0)~string, "054752,,744452", "shr 193"
count = count + 1
call assertEq (Oct("565555,,730401") + Oct("530264,,705165"))~string, "316042,,635566", "add 194"
count = count + 1
call assertEq (Oct("565555,,730401") - Oct("530264,,705165"))~string, "035271,,023214", "sub 194"
count = count + 1
call assertEq (Oct("565555,,730401") & Oct("530264,,705165"))~string, "520044,,700001", "and 194"
count = count + 1
call assertEq (Oct("565555,,730401") | Oct("530264,,705165"))~string, "575775,,735565", "or 194"
count = count + 1
call assertEq (Oct("565555,,730401") && Oct("530264,,705165"))~string, "055731,,035564", "xor 194"
count = count + 1
call assertEq Oct("565555,,730401")~shl(14)~string, "675420,,040000", "shl 194"
count = count + 1
call assertEq Oct("565555,,730401")~shr(14)~string, "000013,,533336", "shr 194"
count = count + 1
call assertEq (Oct("335775,,723556") + Oct("236766,,223636"))~string, "574764,,147414", "add 195"
count = count + 1
call assertEq (Oct("335775,,723556") - Oct("236766,,223636"))~string, "077007,,477720", "sub 195"
count = count + 1
call assertEq (Oct("335775,,723556") & Oct("236766,,223636"))~string, "234764,,223416", "and 195"
count = count + 1
call assertEq (Oct("335775,,723556") | Oct("236766,,223636"))~string, "337777,,723776", "or 195"
count = count + 1
call assertEq (Oct("335775,,723556") && Oct("236766,,223636"))~string, "103013,,500360", "xor 195"
count = count + 1
call assertEq Oct("335775,,723556")~shl(3)~string, "357757,,235560", "shl 195"
count = count + 1
call assertEq Oct("335775,,723556")~shr(3)~string, "033577,,572355", "shr 195"
count = count + 1
call assertEq (Oct("616275,,000744") + Oct("577616,,077004"))~string, "416113,,077750", "add 196"
count = count + 1
call assertEq (Oct("616275,,000744") - Oct("577616,,077004"))~string, "016456,,701740", "sub 196"
count = count + 1
call assertEq (Oct("616275,,000744") & Oct("577616,,077004"))~string, "416214,,000004", "and 196"
count = count + 1
call assertEq (Oct("616275,,000744") | Oct("577616,,077004"))~string, "777677,,077744", "or 196"
count = count + 1
call assertEq (Oct("616275,,000744") && Oct("577616,,077004"))~string, "361463,,077740", "xor 196"
count = count + 1
call assertEq Oct("616275,,000744")~shl(25)~string, "171000,,000000", "shl 196"
count = count + 1
call assertEq Oct("616275,,000744")~shr(25)~string, "000000,,003071", "shr 196"
count = count + 1
call assertEq (Oct("400033,,605113") + Oct("302564,,524651"))~string, "702620,,331764", "add 197"
count = count + 1
call assertEq (Oct("400033,,605113") - Oct("302564,,524651"))~string, "075247,,060242", "sub 197"
count = count + 1
call assertEq (Oct("400033,,605113") & Oct("302564,,524651"))~string, "000020,,404011", "and 197"
count = count + 1
call assertEq (Oct("400033,,605113") | Oct("302564,,524651"))~string, "702577,,725753", "or 197"
count = count + 1
call assertEq (Oct("400033,,605113") && Oct("302564,,524651"))~string, "702557,,321742", "xor 197"
count = count + 1
call assertEq Oct("400033,,605113")~shl(32)~string, "540000,,000000", "shl 197"
count = count + 1
call assertEq Oct("400033,,605113")~shr(32)~string, "000000,,000010", "shr 197"
count = count + 1
call assertEq (Oct("514525,,511655") + Oct("732554,,101610"))~string, "447301,,613465", "add 198"
count = count + 1
call assertEq (Oct("514525,,511655") - Oct("732554,,101610"))~string, "561751,,410045", "sub 198"
count = count + 1
call assertEq (Oct("514525,,511655") & Oct("732554,,101610"))~string, "510504,,101610", "and 198"
count = count + 1
call assertEq (Oct("514525,,511655") | Oct("732554,,101610"))~string, "736575,,511655", "or 198"
count = count + 1
call assertEq (Oct("514525,,511655") && Oct("732554,,101610"))~string, "226071,,410045", "xor 198"
count = count + 1
call assertEq Oct("514525,,511655")~shl(19)~string, "223532,,000000", "shl 198"
count = count + 1
call assertEq Oct("514525,,511655")~shr(19)~string, "000000,,246252", "shr 198"
count = count + 1
call assertEq (Oct("553330,,440363") + Oct("501415,,013550"))~string, "254745,,454133", "add 199"
count = count + 1
call assertEq (Oct("553330,,440363") - Oct("501415,,013550"))~string, "051713,,424613", "sub 199"
count = count + 1
call assertEq (Oct("553330,,440363") & Oct("501415,,013550"))~string, "501010,,000140", "and 199"
count = count + 1
call assertEq (Oct("553330,,440363") | Oct("501415,,013550"))~string, "553735,,453773", "or 199"
count = count + 1
call assertEq (Oct("553330,,440363") && Oct("501415,,013550"))~string, "052725,,453633", "xor 199"
count = count + 1
call assertEq Oct("553330,,440363")~shl(24)~string, "036300,,000000", "shl 199"
count = count + 1
call assertEq Oct("553330,,440363")~shr(24)~string, "000000,,005533", "shr 199"
count = count + 1
call assertEq (Oct("215253,,652046") + Oct("377020,,433560"))~string, "614274,,305626", "add 200"
count = count + 1
call assertEq (Oct("215253,,652046") - Oct("377020,,433560"))~string, "616233,,216266", "sub 200"
count = count + 1
call assertEq (Oct("215253,,652046") & Oct("377020,,433560"))~string, "215000,,412040", "and 200"
count = count + 1
call assertEq (Oct("215253,,652046") | Oct("377020,,433560"))~string, "377273,,673566", "or 200"
count = count + 1
call assertEq (Oct("215253,,652046") && Oct("377020,,433560"))~string, "162273,,261526", "xor 200"
count = count + 1
call assertEq Oct("215253,,652046")~shl(35)~string, "000000,,000000", "shl 200"
count = count + 1
call assertEq Oct("215253,,652046")~shr(35)~string, "000000,,000000", "shr 200"
count = count + 1
call assertEq (Oct("600647,,306626") + Oct("472754,,045075"))~string, "273623,,353723", "add 201"
count = count + 1
call assertEq (Oct("600647,,306626") - Oct("472754,,045075"))~string, "105673,,241531", "sub 201"
count = count + 1
call assertEq (Oct("600647,,306626") & Oct("472754,,045075"))~string, "400644,,004024", "and 201"
count = count + 1
call assertEq (Oct("600647,,306626") | Oct("472754,,045075"))~string, "672757,,347677", "or 201"
count = count + 1
call assertEq (Oct("600647,,306626") && Oct("472754,,045075"))~string, "272113,,343653", "xor 201"
count = count + 1
call assertEq Oct("600647,,306626")~shl(39)~string, "000000,,000000", "shl 201"
count = count + 1
call assertEq Oct("600647,,306626")~shr(39)~string, "000000,,000000", "shr 201"
count = count + 1
call assertEq (Oct("253451,,716655") + Oct("252357,,446635"))~string, "526031,,365512", "add 202"
count = count + 1
call assertEq (Oct("253451,,716655") - Oct("252357,,446635"))~string, "001072,,250020", "sub 202"
count = count + 1
call assertEq (Oct("253451,,716655") & Oct("252357,,446635"))~string, "252051,,406615", "and 202"
count = count + 1
call assertEq (Oct("253451,,716655") | Oct("252357,,446635"))~string, "253757,,756675", "or 202"
count = count + 1
call assertEq (Oct("253451,,716655") && Oct("252357,,446635"))~string, "001706,,350060", "xor 202"
count = count + 1
call assertEq Oct("253451,,716655")~shl(30)~string, "550000,,000000", "shl 202"
count = count + 1
call assertEq Oct("253451,,716655")~shr(30)~string, "000000,,000025", "shr 202"
count = count + 1
call assertEq (Oct("123405,,664200") + Oct("576537,,250302"))~string, "722145,,134502", "add 203"
count = count + 1
call assertEq (Oct("123405,,664200") - Oct("576537,,250302"))~string, "324646,,413676", "sub 203"
count = count + 1
call assertEq (Oct("123405,,664200") & Oct("576537,,250302"))~string, "122405,,240200", "and 203"
count = count + 1
call assertEq (Oct("123405,,664200") | Oct("576537,,250302"))~string, "577537,,674302", "or 203"
count = count + 1
call assertEq (Oct("123405,,664200") && Oct("576537,,250302"))~string, "455132,,434102", "xor 203"
count = count + 1
call assertEq Oct("123405,,664200")~shl(12)~string, "056642,,000000", "shl 203"
count = count + 1
call assertEq Oct("123405,,664200")~shr(12)~string, "000012,,340566", "shr 203"
count = count + 1
call assertEq (Oct("725204,,726275") + Oct("375132,,176130"))~string, "322337,,124425", "add 204"
count = count + 1
call assertEq (Oct("725204,,726275") - Oct("375132,,176130"))~string, "330052,,530145", "sub 204"
count = count + 1
call assertEq (Oct("725204,,726275") & Oct("375132,,176130"))~string, "325000,,126030", "and 204"
count = count + 1
call assertEq (Oct("725204,,726275") | Oct("375132,,176130"))~string, "775336,,776375", "or 204"
count = count + 1
call assertEq (Oct("725204,,726275") && Oct("375132,,176130"))~string, "450336,,650345", "xor 204"
count = count + 1
call assertEq Oct("725204,,726275")~shl(12)~string, "047262,,750000", "shl 204"
count = count + 1
call assertEq Oct("725204,,726275")~shr(12)~string, "000072,,520472", "shr 204"
count = count + 1
call assertEq (Oct("147715,,364650") + Oct("616164,,501056"))~string, "766102,,065726", "add 205"
count = count + 1
call assertEq (Oct("147715,,364650") - Oct("616164,,501056"))~string, "331530,,663572", "sub 205"
count = count + 1
call assertEq (Oct("147715,,364650") & Oct("616164,,501056"))~string, "006104,,100050", "and 205"
count = count + 1
call assertEq (Oct("147715,,364650") | Oct("616164,,501056"))~string, "757775,,765656", "or 205"
count = count + 1
call assertEq (Oct("147715,,364650") && Oct("616164,,501056"))~string, "751671,,665606", "xor 205"
count = count + 1
call assertEq Oct("147715,,364650")~shl(20)~string, "723240,,000000", "shl 205"
count = count + 1
call assertEq Oct("147715,,364650")~shr(20)~string, "000000,,031763", "shr 205"
count = count + 1
call assertEq (Oct("052103,,273477") + Oct("347325,,334171"))~string, "421430,,627670", "add 206"
count = count + 1
call assertEq (Oct("052103,,273477") - Oct("347325,,334171"))~string, "502555,,737306", "sub 206"
count = count + 1
call assertEq (Oct("052103,,273477") & Oct("347325,,334171"))~string, "042101,,230071", "and 206"
count = count + 1
call assertEq (Oct("052103,,273477") | Oct("347325,,334171"))~string, "357327,,377577", "or 206"
count = count + 1
call assertEq (Oct("052103,,273477") && Oct("347325,,334171"))~string, "315226,,147506", "xor 206"
count = count + 1
call assertEq Oct("052103,,273477")~shl(38)~string, "000000,,000000", "shl 206"
count = count + 1
call assertEq Oct("052103,,273477")~shr(38)~string, "000000,,000000", "shr 206"
count = count + 1
call assertEq (Oct("021554,,616561") + Oct("447162,,476314"))~string, "470737,,315075", "add 207"
count = count + 1
call assertEq (Oct("021554,,616561") - Oct("447162,,476314"))~string, "352372,,120245", "sub 207"
count = count + 1
call assertEq (Oct("021554,,616561") & Oct("447162,,476314"))~string, "001140,,416100", "and 207"
count = count + 1
call assertEq (Oct("021554,,616561") | Oct("447162,,476314"))~string, "467576,,676775", "or 207"
count = count + 1
call assertEq (Oct("021554,,616561") && Oct("447162,,476314"))~string, "466436,,260675", "xor 207"
count = count + 1
call assertEq Oct("021554,,616561")~shl(3)~string, "215546,,165610", "shl 207"
count = count + 1
call assertEq Oct("021554,,616561")~shr(3)~string, "002155,,461656", "shr 207"
count = count + 1
call assertEq (Oct("503227,,232036") + Oct("615043,,141662"))~string, "320272,,373720", "add 208"
count = count + 1
call assertEq (Oct("503227,,232036") - Oct("615043,,141662"))~string, "666164,,070154", "sub 208"
count = count + 1
call assertEq (Oct("503227,,232036") & Oct("615043,,141662"))~string, "401003,,000022", "and 208"
count = count + 1
call assertEq (Oct("503227,,232036") | Oct("615043,,141662"))~string, "717267,,373676", "or 208"
count = count + 1
call assertEq (Oct("503227,,232036") && Oct("615043,,141662"))~string, "316264,,373654", "xor 208"
count = count + 1
call assertEq Oct("503227,,232036")~shl(36)~string, "000000,,000000", "shl 208"
count = count + 1
call assertEq Oct("503227,,232036")~shr(36)~string, "000000,,000000", "shr 208"
count = count + 1
call assertEq (Oct("620247,,735351") + Oct("446777,,307502"))~string, "267247,,245053", "add 209"
count = count + 1
call assertEq (Oct("620247,,735351") - Oct("446777,,307502"))~string, "151250,,425647", "sub 209"
count = count + 1
call assertEq (Oct("620247,,735351") & Oct("446777,,307502"))~string, "400247,,305100", "and 209"
count = count + 1
call assertEq (Oct("620247,,735351") | Oct("446777,,307502"))~string, "666777,,737753", "or 209"
count = count + 1
call assertEq (Oct("620247,,735351") && Oct("446777,,307502"))~string, "266530,,432653", "xor 209"
count = count + 1
call assertEq Oct("620247,,735351")~shl(7)~string, "051767,,272200", "shl 209"
count = count + 1
call assertEq Oct("620247,,735351")~shr(7)~string, "003101,,237565", "shr 209"
count = count + 1
call assertEq (Oct("052527,,415402") + Oct("130631,,175762"))~string, "203360,,613364", "add 210"
count = count + 1
call assertEq (Oct("052527,,415402") - Oct("130631,,175762"))~string, "721676,,217420", "sub 210"
count = count + 1
call assertEq (Oct("052527,,415402") & Oct("130631,,175762"))~string, "010421,,015402", "and 210"
count = count + 1
call assertEq (Oct("052527,,415402") | Oct("130631,,175762"))~string, "172737,,575762", "or 210"
count = count + 1
call assertEq (Oct("052527,,415402") && Oct("130631,,175762"))~string, "162316,,560360", "xor 210"
count = count + 1
call assertEq Oct("052527,,415402")~shl(11)~string, "536066,,010000", "shl 210"
count = count + 1
call assertEq Oct("052527,,415402")~shr(11)~string, "000012,,525703", "shr 210"
count = count + 1
call assertEq (Oct("771330,,302761") + Oct("063705,,041166"))~string, "055235,,344147", "add 211"
count = count + 1
call assertEq (Oct("771330,,302761") - Oct("063705,,041166"))~string, "705423,,241573", "sub 211"
count = count + 1
call assertEq (Oct("771330,,302761") & Oct("063705,,041166"))~string, "061300,,000160", "and 211"
count = count + 1
call assertEq (Oct("771330,,302761") | Oct("063705,,041166"))~string, "773735,,343767", "or 211"
count = count + 1
call assertEq (Oct("771330,,302761") && Oct("063705,,041166"))~string, "712435,,343607", "xor 211"
count = count + 1
call assertEq Oct("771330,,302761")~shl(33)~string, "100000,,000000", "shl 211"
count = count + 1
call assertEq Oct("771330,,302761")~shr(33)~string, "000000,,000007", "shr 211"
count = count + 1
call assertEq (Oct("204273,,222605") + Oct("050366,,604003"))~string, "254662,,026610", "add 212"
count = count + 1
call assertEq (Oct("204273,,222605") - Oct("050366,,604003"))~string, "133704,,416602", "sub 212"
count = count + 1
call assertEq (Oct("204273,,222605") & Oct("050366,,604003"))~string, "000262,,200001", "and 212"
count = count + 1
call assertEq (Oct("204273,,222605") | Oct("050366,,604003"))~string, "254377,,626607", "or 212"
count = count + 1
call assertEq (Oct("204273,,222605") && Oct("050366,,604003"))~string, "254115,,426606", "xor 212"
count = count + 1
call assertEq Oct("204273,,222605")~shl(12)~string, "732226,,050000", "shl 212"
count = count + 1
call assertEq Oct("204273,,222605")~shr(12)~string, "000020,,427322", "shr 212"
count = count + 1
call assertEq (Oct("630141,,211640") + Oct("352562,,755442"))~string, "202724,,167302", "add 213"
count = count + 1
call assertEq (Oct("630141,,211640") - Oct("352562,,755442"))~string, "255356,,234176", "sub 213"
count = count + 1
call assertEq (Oct("630141,,211640") & Oct("352562,,755442"))~string, "210140,,211440", "and 213"
count = count + 1
call assertEq (Oct("630141,,211640") | Oct("352562,,755442"))~string, "772563,,755642", "or 213"
count = count + 1
call assertEq (Oct("630141,,211640") && Oct("352562,,755442"))~string, "562423,,544202", "xor 213"
count = count + 1
call assertEq Oct("630141,,211640")~shl(13)~string, "024235,,000000", "shl 213"
count = count + 1
call assertEq Oct("630141,,211640")~shr(13)~string, "000031,,406050", "shr 213"
count = count + 1
call assertEq (Oct("601464,,202313") + Oct("331445,,550322"))~string, "133131,,752635", "add 214"
count = count + 1
call assertEq (Oct("601464,,202313") - Oct("331445,,550322"))~string, "250016,,431771", "sub 214"
count = count + 1
call assertEq (Oct("601464,,202313") & Oct("331445,,550322"))~string, "201444,,000302", "and 214"
count = count + 1
call assertEq (Oct("601464,,202313") | Oct("331445,,550322"))~string, "731465,,752333", "or 214"
count = count + 1
call assertEq (Oct("601464,,202313") && Oct("331445,,550322"))~string, "530021,,752031", "xor 214"
count = count + 1
call assertEq Oct("601464,,202313")~shl(10)~string, "150404,,626000", "shl 214"
count = count + 1
call assertEq Oct("601464,,202313")~shr(10)~string, "000300,,632101", "shr 214"
count = count + 1
call assertEq (Oct("671017,,225445") + Oct("625344,,705477"))~string, "516364,,133144", "add 215"
count = count + 1
call assertEq (Oct("671017,,225445") - Oct("625344,,705477"))~string, "043452,,317746", "sub 215"
count = count + 1
call assertEq (Oct("671017,,225445") & Oct("625344,,705477"))~string, "621004,,205445", "and 215"
count = count + 1
call assertEq (Oct("671017,,225445") | Oct("625344,,705477"))~string, "675357,,725477", "or 215"
count = count + 1
call assertEq (Oct("671017,,225445") && Oct("625344,,705477"))~string, "054353,,520032", "xor 215"
count = count + 1
call assertEq Oct("671017,,225445")~shl(1)~string, "562036,,453112", "shl 215"
count = count + 1
call assertEq Oct("671017,,225445")~shr(1)~string, "334407,,512622", "shr 215"
count = count + 1
call assertEq (Oct("155535,,720410") + Oct("607673,,212276"))~string, "765431,,132706", "add 216"
count = count + 1
call assertEq (Oct("155535,,720410") - Oct("607673,,212276"))~string, "345642,,506112", "sub 216"
count = count + 1
call assertEq (Oct("155535,,720410") & Oct("607673,,212276"))~string, "005431,,200010", "and 216"
count = count + 1
call assertEq (Oct("155535,,720410") | Oct("607673,,212276"))~string, "757777,,732676", "or 216"
count = count + 1
call assertEq (Oct("155535,,720410") && Oct("607673,,212276"))~string, "752346,,532666", "xor 216"
count = count + 1
call assertEq Oct("155535,,720410")~shl(33)~string, "000000,,000000", "shl 216"
count = count + 1
call assertEq Oct("155535,,720410")~shr(33)~string, "000000,,000001", "shr 216"
count = count + 1
call assertEq (Oct("615220,,256425") + Oct("337105,,336517"))~string, "154325,,615144", "add 217"
count = count + 1
call assertEq (Oct("615220,,256425") - Oct("337105,,336517"))~string, "256112,,717706", "sub 217"
count = count + 1
call assertEq (Oct("615220,,256425") & Oct("337105,,336517"))~string, "215000,,216405", "and 217"
count = count + 1
call assertEq (Oct("615220,,256425") | Oct("337105,,336517"))~string, "737325,,376537", "or 217"
count = count + 1
call assertEq (Oct("615220,,256425") && Oct("337105,,336517"))~string, "522325,,160132", "xor 217"
count = count + 1
call assertEq Oct("615220,,256425")~shl(24)~string, "642500,,000000", "shl 217"
count = count + 1
call assertEq Oct("615220,,256425")~shr(24)~string, "000000,,006152", "shr 217"
count = count + 1
call assertEq (Oct("111661,,237307") + Oct("114650,,032454"))~string, "226531,,271763", "add 218"
count = count + 1
call assertEq (Oct("111661,,237307") - Oct("114650,,032454"))~string, "775011,,204633", "sub 218"
count = count + 1
call assertEq (Oct("111661,,237307") & Oct("114650,,032454"))~string, "110640,,032004", "and 218"
count = count + 1
call assertEq (Oct("111661,,237307") | Oct("114650,,032454"))~string, "115671,,237757", "or 218"
count = count + 1
call assertEq (Oct("111661,,237307") && Oct("114650,,032454"))~string, "005031,,205753", "xor 218"
count = count + 1
call assertEq Oct("111661,,237307")~shl(6)~string, "166123,,730700", "shl 218"
count = count + 1
call assertEq Oct("111661,,237307")~shr(6)~string, "001116,,612373", "shr 218"
count = count + 1
call assertEq (Oct("240444,,762107") + Oct("567576,,473142"))~string, "030243,,455251", "add 219"
count = count + 1
call assertEq (Oct("240444,,762107") - Oct("567576,,473142"))~string, "450646,,266745", "sub 219"
count = count + 1
call assertEq (Oct("240444,,762107") & Oct("567576,,473142"))~string, "040444,,462102", "and 219"
count = count + 1
call assertEq (Oct("240444,,762107") | Oct("567576,,473142"))~string, "767576,,773147", "or 219"
count = count + 1
call assertEq (Oct("240444,,762107") && Oct("567576,,473142"))~string, "727132,,311045", "xor 219"
count = count + 1
call assertEq Oct("240444,,762107")~shl(17)~string, "371043,,400000", "shl 219"
count = count + 1
call assertEq Oct("240444,,762107")~shr(17)~string, "000000,,501111", "shr 219"
count = count + 1
call assertEq (Oct("216316,,713241") + Oct("560524,,742113"))~string, "777043,,655354", "add 220"
count = count + 1
call assertEq (Oct("216316,,713241") - Oct("560524,,742113"))~string, "435571,,751126", "sub 220"
count = count + 1
call assertEq (Oct("216316,,713241") & Oct("560524,,742113"))~string, "000104,,702001", "and 220"
count = count + 1
call assertEq (Oct("216316,,713241") | Oct("560524,,742113"))~string, "776736,,753353", "or 220"
count = count + 1
call assertEq (Oct("216316,,713241") && Oct("560524,,742113"))~string, "776632,,051352", "xor 220"
count = count + 1
call assertEq Oct("216316,,713241")~shl(38)~string, "000000,,000000", "shl 220"
count = count + 1
call assertEq Oct("216316,,713241")~shr(38)~string, "000000,,000000", "shr 220"
count = count + 1
call assertEq (Oct("652311,,406172") + Oct("167674,,064704"))~string, "042205,,473076", "add 221"
count = count + 1
call assertEq (Oct("652311,,406172") - Oct("167674,,064704"))~string, "462415,,321266", "sub 221"
count = count + 1
call assertEq (Oct("652311,,406172") & Oct("167674,,064704"))~string, "042210,,004100", "and 221"
count = count + 1
call assertEq (Oct("652311,,406172") | Oct("167674,,064704"))~string, "777775,,466776", "or 221"
count = count + 1
call assertEq (Oct("652311,,406172") && Oct("167674,,064704"))~string, "735565,,462676", "xor 221"
count = count + 1
call assertEq Oct("652311,,406172")~shl(20)~string, "030750,,000000", "shl 221"
count = count + 1
call assertEq Oct("652311,,406172")~shr(20)~string, "000000,,152462", "shr 221"
count = count + 1
call assertEq (Oct("714154,,242562") + Oct("615470,,553074"))~string, "531645,,015656", "add 222"
count = count + 1
call assertEq (Oct("714154,,242562") - Oct("615470,,553074"))~string, "076463,,467466", "sub 222"
count = count + 1
call assertEq (Oct("714154,,242562") & Oct("615470,,553074"))~string, "614050,,042060", "and 222"
count = count + 1
call assertEq (Oct("714154,,242562") | Oct("615470,,553074"))~string, "715574,,753576", "or 222"
count = count + 1
call assertEq (Oct("714154,,242562") && Oct("615470,,553074"))~string, "101524,,711516", "xor 222"
count = count + 1
call assertEq Oct("714154,,242562")~shl(37)~string, "000000,,000000", "shl 222"
count = count + 1
call assertEq Oct("714154,,242562")~shr(37)~string, "000000,,000000", "shr 222"
count = count + 1
call assertEq (Oct("141552,,464340") + Oct("655120,,425475"))~string, "016673,,112035", "add 223"
count = count + 1
call assertEq (Oct("141552,,464340") - Oct("655120,,425475"))~string, "264432,,036643", "sub 223"
count = count + 1
call assertEq (Oct("141552,,464340") & Oct("655120,,425475"))~string, "041100,,424040", "and 223"
count = count + 1
call assertEq (Oct("141552,,464340") | Oct("655120,,425475"))~string, "755572,,465775", "or 223"
count = count + 1
call assertEq (Oct("141552,,464340") && Oct("655120,,425475"))~string, "714472,,041735", "xor 223"
count = count + 1
call assertEq Oct("141552,,464340")~shl(36)~string, "000000,,000000", "shl 223"
count = count + 1
call assertEq Oct("141552,,464340")~shr(36)~string, "000000,,000000", "shr 223"
count = count + 1
call assertEq (Oct("302476,,260774") + Oct("616014,,606640"))~string, "120513,,067634", "add 224"
count = count + 1
call assertEq (Oct("302476,,260774") - Oct("616014,,606640"))~string, "464461,,452134", "sub 224"
count = count + 1
call assertEq (Oct("302476,,260774") & Oct("616014,,606640"))~string, "202014,,200640", "and 224"
count = count + 1
call assertEq (Oct("302476,,260774") | Oct("616014,,606640"))~string, "716476,,666774", "or 224"
count = count + 1
call assertEq (Oct("302476,,260774") && Oct("616014,,606640"))~string, "514462,,466134", "xor 224"
count = count + 1
call assertEq Oct("302476,,260774")~shl(7)~string, "517454,,177000", "shl 224"
count = count + 1
call assertEq Oct("302476,,260774")~shr(7)~string, "001412,,371303", "shr 224"
count = count + 1
call assertEq (Oct("533735,,621445") + Oct("206053,,060167"))~string, "742010,,701634", "add 225"
count = count + 1
call assertEq (Oct("533735,,621445") - Oct("206053,,060167"))~string, "325662,,541256", "sub 225"
count = count + 1
call assertEq (Oct("533735,,621445") & Oct("206053,,060167"))~string, "002011,,020045", "and 225"
count = count + 1
call assertEq (Oct("533735,,621445") | Oct("206053,,060167"))~string, "737777,,661567", "or 225"
count = count + 1
call assertEq (Oct("533735,,621445") && Oct("206053,,060167"))~string, "735766,,641522", "xor 225"
count = count + 1
call assertEq Oct("533735,,621445")~shl(11)~string, "567106,,224000", "shl 225"
count = count + 1
call assertEq Oct("533735,,621445")~shr(11)~string, "000126,,767344", "shr 225"
count = count + 1
call assertEq (Oct("275166,,275755") + Oct("514314,,437644"))~string, "011502,,735621", "add 226"
count = count + 1
call assertEq (Oct("275166,,275755") - Oct("514314,,437644"))~string, "560651,,636111", "sub 226"
count = count + 1
call assertEq (Oct("275166,,275755") & Oct("514314,,437644"))~string, "014104,,035644", "and 226"
count = count + 1
call assertEq (Oct("275166,,275755") | Oct("514314,,437644"))~string, "775376,,677755", "or 226"
count = count + 1
call assertEq (Oct("275166,,275755") && Oct("514314,,437644"))~string, "761272,,642111", "xor 226"
count = count + 1
call assertEq Oct("275166,,275755")~shl(23)~string, "676640,,000000", "shl 226"
count = count + 1
call assertEq Oct("275166,,275755")~shr(23)~string, "000000,,005723", "shr 226"
count = count + 1
call assertEq (Oct("221161,,122024") + Oct("143166,,366076"))~string, "364347,,510122", "add 227"
count = count + 1
call assertEq (Oct("221161,,122024") - Oct("143166,,366076"))~string, "055772,,533726", "sub 227"
count = count + 1
call assertEq (Oct("221161,,122024") & Oct("143166,,366076"))~string, "001160,,122024", "and 227"
count = count + 1
call assertEq (Oct("221161,,122024") | Oct("143166,,366076"))~string, "363167,,366076", "or 227"
count = count + 1
call assertEq (Oct("221161,,122024") && Oct("143166,,366076"))~string, "362007,,244052", "xor 227"
count = count + 1
call assertEq Oct("221161,,122024")~shl(32)~string, "200000,,000000", "shl 227"
count = count + 1
call assertEq Oct("221161,,122024")~shr(32)~string, "000000,,000004", "shr 227"
count = count + 1
call assertEq (Oct("312223,,533371") + Oct("710441,,464350"))~string, "222665,,217741", "add 228"
count = count + 1
call assertEq (Oct("312223,,533371") - Oct("710441,,464350"))~string, "401562,,047021", "sub 228"
count = count + 1
call assertEq (Oct("312223,,533371") & Oct("710441,,464350"))~string, "310001,,420350", "and 228"
count = count + 1
call assertEq (Oct("312223,,533371") | Oct("710441,,464350"))~string, "712663,,577371", "or 228"
count = count + 1
call assertEq (Oct("312223,,533371") && Oct("710441,,464350"))~string, "402662,,157021", "xor 228"
count = count + 1
call assertEq Oct("312223,,533371")~shl(18)~string, "533371,,000000", "shl 228"
count = count + 1
call assertEq Oct("312223,,533371")~shr(18)~string, "000000,,312223", "shr 228"
count = count + 1
call assertEq (Oct("432656,,772673") + Oct("674162,,710306"))~string, "327041,,703201", "add 229"
count = count + 1
call assertEq (Oct("432656,,772673") - Oct("674162,,710306"))~string, "536474,,062365", "sub 229"
count = count + 1
call assertEq (Oct("432656,,772673") & Oct("674162,,710306"))~string, "430042,,710202", "and 229"
count = count + 1
call assertEq (Oct("432656,,772673") | Oct("674162,,710306"))~string, "676776,,772777", "or 229"
count = count + 1
call assertEq (Oct("432656,,772673") && Oct("674162,,710306"))~string, "246734,,062575", "xor 229"
count = count + 1
call assertEq Oct("432656,,772673")~shl(24)~string, "267300,,000000", "shl 229"
count = count + 1
call assertEq Oct("432656,,772673")~shr(24)~string, "000000,,004326", "shr 229"
count = count + 1
call assertEq (Oct("171763,,025517") + Oct("216410,,677264"))~string, "410373,,725003", "add 230"
count = count + 1
call assertEq (Oct("171763,,025517") - Oct("216410,,677264"))~string, "753352,,126233", "sub 230"
count = count + 1
call assertEq (Oct("171763,,025517") & Oct("216410,,677264"))~string, "010400,,025004", "and 230"
count = count + 1
call assertEq (Oct("171763,,025517") | Oct("216410,,677264"))~string, "377773,,677777", "or 230"
count = count + 1
call assertEq (Oct("171763,,025517") && Oct("216410,,677264"))~string, "367373,,652773", "xor 230"
count = count + 1
call assertEq Oct("171763,,025517")~shl(30)~string, "170000,,000000", "shl 230"
count = count + 1
call assertEq Oct("171763,,025517")~shr(30)~string, "000000,,000017", "shr 230"
count = count + 1
call assertEq (Oct("145765,,232744") + Oct("145246,,637235"))~string, "313234,,072201", "add 231"
count = count + 1
call assertEq (Oct("145765,,232744") - Oct("145246,,637235"))~string, "000516,,373507", "sub 231"
count = count + 1
call assertEq (Oct("145765,,232744") & Oct("145246,,637235"))~string, "145244,,232204", "and 231"
count = count + 1
call assertEq (Oct("145765,,232744") | Oct("145246,,637235"))~string, "145767,,637775", "or 231"
count = count + 1
call assertEq (Oct("145765,,232744") && Oct("145246,,637235"))~string, "000523,,405571", "xor 231"
count = count + 1
call assertEq Oct("145765,,232744")~shl(13)~string, "524657,,100000", "shl 231"
count = count + 1
call assertEq Oct("145765,,232744")~shr(13)~string, "000006,,277251", "shr 231"
count = count + 1
call assertEq (Oct("725232,,734167") + Oct("146574,,250743"))~string, "074027,,205132", "add 232"
count = count + 1
call assertEq (Oct("725232,,734167") - Oct("146574,,250743"))~string, "556436,,463224", "sub 232"
count = count + 1
call assertEq (Oct("725232,,734167") & Oct("146574,,250743"))~string, "104030,,210143", "and 232"
count = count + 1
call assertEq (Oct("725232,,734167") | Oct("146574,,250743"))~string, "767776,,774767", "or 232"
count = count + 1
call assertEq (Oct("725232,,734167") && Oct("146574,,250743"))~string, "663746,,564624", "xor 232"
count = count + 1
call assertEq Oct("725232,,734167")~shl(36)~string, "000000,,000000", "shl 232"
count = count + 1
call assertEq Oct("725232,,734167")~shr(36)~string, "000000,,000000", "shr 232"
count = count + 1
call assertEq (Oct("366672,,041030") + Oct("426331,,076236"))~string, "015223,,137266", "add 233"
count = count + 1
call assertEq (Oct("366672,,041030") - Oct("426331,,076236"))~string, "740340,,742572", "sub 233"
count = count + 1
call assertEq (Oct("366672,,041030") & Oct("426331,,076236"))~string, "026230,,040030", "and 233"
count = count + 1
call assertEq (Oct("366672,,041030") | Oct("426331,,076236"))~string, "766773,,077236", "or 233"
count = count + 1
call assertEq (Oct("366672,,041030") && Oct("426331,,076236"))~string, "740543,,037206", "xor 233"
count = count + 1
call assertEq Oct("366672,,041030")~shl(31)~string, "600000,,000000", "shl 233"
count = count + 1
call assertEq Oct("366672,,041030")~shr(31)~string, "000000,,000017", "shr 233"
count = count + 1
call assertEq (Oct("335053,,444110") + Oct("614111,,145447"))~string, "151164,,611557", "add 234"
count = count + 1
call assertEq (Oct("335053,,444110") - Oct("614111,,145447"))~string, "520742,,276441", "sub 234"
count = count + 1
call assertEq (Oct("335053,,444110") & Oct("614111,,145447"))~string, "214011,,044000", "and 234"
count = count + 1
call assertEq (Oct("335053,,444110") | Oct("614111,,145447"))~string, "735153,,545557", "or 234"
count = count + 1
call assertEq (Oct("335053,,444110") && Oct("614111,,145447"))~string, "521142,,501557", "xor 234"
count = count + 1
call assertEq Oct("335053,,444110")~shl(10)~string, "127110,,220000", "shl 234"
count = count + 1
call assertEq Oct("335053,,444110")~shr(10)~string, "000156,,425622", "shr 234"
count = count + 1
call assertEq (Oct("444733,,370471") + Oct("336373,,604546"))~string, "003327,,175237", "add 235"
count = count + 1
call assertEq (Oct("444733,,370471") - Oct("336373,,604546"))~string, "106337,,563723", "sub 235"
count = count + 1
call assertEq (Oct("444733,,370471") & Oct("336373,,604546"))~string, "004333,,200440", "and 235"
count = count + 1
call assertEq (Oct("444733,,370471") | Oct("336373,,604546"))~string, "776773,,774577", "or 235"
count = count + 1
call assertEq (Oct("444733,,370471") && Oct("336373,,604546"))~string, "772440,,574137", "xor 235"
count = count + 1
call assertEq Oct("444733,,370471")~shl(39)~string, "000000,,000000", "shl 235"
count = count + 1
call assertEq Oct("444733,,370471")~shr(39)~string, "000000,,000000", "shr 235"
count = count + 1
call assertEq (Oct("575724,,332070") + Oct("471517,,527421"))~string, "267444,,061511", "add 236"
count = count + 1
call assertEq (Oct("575724,,332070") - Oct("471517,,527421"))~string, "104204,,602447", "sub 236"
count = count + 1
call assertEq (Oct("575724,,332070") & Oct("471517,,527421"))~string, "471504,,122020", "and 236"
count = count + 1
call assertEq (Oct("575724,,332070") | Oct("471517,,527421"))~string, "575737,,737471", "or 236"
count = count + 1
call assertEq (Oct("575724,,332070") && Oct("471517,,527421"))~string, "104233,,615451", "xor 236"
count = count + 1
call assertEq Oct("575724,,332070")~shl(25)~string, "416000,,000000", "shl 236"
count = count + 1
call assertEq Oct("575724,,332070")~shr(25)~string, "000000,,002767", "shr 236"
count = count + 1
call assertEq (Oct("335565,,551417") + Oct("200672,,416425"))~string, "536460,,170044", "add 237"
count = count + 1
call assertEq (Oct("335565,,551417") - Oct("200672,,416425"))~string, "134673,,132772", "sub 237"
count = count + 1
call assertEq (Oct("335565,,551417") & Oct("200672,,416425"))~string, "200460,,410405", "and 237"
count = count + 1
call assertEq (Oct("335565,,551417") | Oct("200672,,416425"))~string, "335777,,557437", "or 237"
count = count + 1
call assertEq (Oct("335565,,551417") && Oct("200672,,416425"))~string, "135317,,147032", "xor 237"
count = count + 1
call assertEq Oct("335565,,551417")~shl(13)~string, "533230,,360000", "shl 237"
count = count + 1
call assertEq Oct("335565,,551417")~shr(13)~string, "000015,,667266", "shr 237"
count = count + 1
call assertEq (Oct("173627,,360560") + Oct("661533,,016450"))~string, "055362,,377230", "add 238"
count = count + 1
call assertEq (Oct("173627,,360560") - Oct("661533,,016450"))~string, "312074,,342110", "sub 238"
count = count + 1
call assertEq (Oct("173627,,360560") & Oct("661533,,016450"))~string, "061423,,000440", "and 238"
count = count + 1
call assertEq (Oct("173627,,360560") | Oct("661533,,016450"))~string, "773737,,376570", "or 238"
count = count + 1
call assertEq (Oct("173627,,360560") && Oct("661533,,016450"))~string, "712314,,376130", "xor 238"
count = count + 1
call assertEq Oct("173627,,360560")~shl(22)~string, "413400,,000000", "shl 238"
count = count + 1
call assertEq Oct("173627,,360560")~shr(22)~string, "000000,,007571", "shr 238"
count = count + 1
call assertEq (Oct("577554,,221052") + Oct("152205,,420302"))~string, "751761,,641354", "add 239"
count = count + 1
call assertEq (Oct("577554,,221052") - Oct("152205,,420302"))~string, "425346,,600550", "sub 239"
count = count + 1
call assertEq (Oct("577554,,221052") & Oct("152205,,420302"))~string, "152004,,020002", "and 239"
count = count + 1
call assertEq (Oct("577554,,221052") | Oct("152205,,420302"))~string, "577755,,621352", "or 239"
count = count + 1
call assertEq (Oct("577554,,221052") && Oct("152205,,420302"))~string, "425751,,601350", "xor 239"
count = count + 1
call assertEq Oct("577554,,221052")~shl(26)~string, "425000,,000000", "shl 239"
count = count + 1
call assertEq Oct("577554,,221052")~shr(26)~string, "000000,,001377", "shr 239"
count = count + 1
call assertEq (Oct("147227,,632756") + Oct("205355,,024453"))~string, "354604,,657431", "add 240"
count = count + 1
call assertEq (Oct("147227,,632756") - Oct("205355,,024453"))~string, "741652,,606303", "sub 240"
count = count + 1
call assertEq (Oct("147227,,632756") & Oct("205355,,024453"))~string, "005205,,020452", "and 240"
count = count + 1
call assertEq (Oct("147227,,632756") | Oct("205355,,024453"))~string, "347377,,636757", "or 240"
count = count + 1
call assertEq (Oct("147227,,632756") && Oct("205355,,024453"))~string, "342172,,616305", "xor 240"
count = count + 1
call assertEq Oct("147227,,632756")~shl(37)~string, "000000,,000000", "shl 240"
count = count + 1
call assertEq Oct("147227,,632756")~shr(37)~string, "000000,,000000", "shr 240"
count = count + 1
call assertEq (Oct("410467,,374676") + Oct("577422,,305260"))~string, "210111,,702156", "add 241"
count = count + 1
call assertEq (Oct("410467,,374676") - Oct("577422,,305260"))~string, "611045,,067416", "sub 241"
count = count + 1
call assertEq (Oct("410467,,374676") & Oct("577422,,305260"))~string, "410422,,304260", "and 241"
count = count + 1
call assertEq (Oct("410467,,374676") | Oct("577422,,305260"))~string, "577467,,375676", "or 241"
count = count + 1
call assertEq (Oct("410467,,374676") && Oct("577422,,305260"))~string, "167045,,071416", "xor 241"
count = count + 1
call assertEq Oct("410467,,374676")~shl(23)~string, "633700,,000000", "shl 241"
count = count + 1
call assertEq Oct("410467,,374676")~shr(23)~string, "000000,,010211", "shr 241"
count = count + 1
call assertEq (Oct("340074,,423157") + Oct("107116,,710601"))~string, "447213,,333760", "add 242"
count = count + 1
call assertEq (Oct("340074,,423157") - Oct("107116,,710601"))~string, "230755,,512356", "sub 242"
count = count + 1
call assertEq (Oct("340074,,423157") & Oct("107116,,710601"))~string, "100014,,400001", "and 242"
count = count + 1
call assertEq (Oct("340074,,423157") | Oct("107116,,710601"))~string, "347176,,733757", "or 242"
count = count + 1
call assertEq (Oct("340074,,423157") && Oct("107116,,710601"))~string, "247162,,333756", "xor 242"
count = count + 1
call assertEq Oct("340074,,423157")~shl(15)~string, "442315,,700000", "shl 242"
count = count + 1
call assertEq Oct("340074,,423157")~shr(15)~string, "000003,,400744", "shr 242"
count = count + 1
call assertEq (Oct("246376,,075401") + Oct("746433,,006061"))~string, "215031,,103462", "add 243"
count = count + 1
call assertEq (Oct("246376,,075401") - Oct("746433,,006061"))~string, "277743,,067320", "sub 243"
count = count + 1
call assertEq (Oct("246376,,075401") & Oct("746433,,006061"))~string, "246032,,004001", "and 243"
count = count + 1
call assertEq (Oct("246376,,075401") | Oct("746433,,006061"))~string, "746777,,077461", "or 243"
count = count + 1
call assertEq (Oct("246376,,075401") && Oct("746433,,006061"))~string, "500745,,073460", "xor 243"
count = count + 1
call assertEq Oct("246376,,075401")~shl(10)~string, "774173,,002000", "shl 243"
count = count + 1
call assertEq Oct("246376,,075401")~shr(10)~string, "000123,,177036", "shr 243"
count = count + 1
call assertEq (Oct("562751,,135040") + Oct("137341,,706505"))~string, "722313,,043545", "add 244"
count = count + 1
call assertEq (Oct("562751,,135040") - Oct("137341,,706505"))~string, "423407,,226333", "sub 244"
count = count + 1
call assertEq (Oct("562751,,135040") & Oct("137341,,706505"))~string, "122341,,104000", "and 244"
count = count + 1
call assertEq (Oct("562751,,135040") | Oct("137341,,706505"))~string, "577751,,737545", "or 244"
count = count + 1
call assertEq (Oct("562751,,135040") && Oct("137341,,706505"))~string, "455410,,633545", "xor 244"
count = count + 1
call assertEq Oct("562751,,135040")~shl(30)~string, "400000,,000000", "shl 244"
count = count + 1
call assertEq Oct("562751,,135040")~shr(30)~string, "000000,,000056", "shr 244"
count = count + 1
call assertEq (Oct("676643,,625127") + Oct("530141,,646236"))~string, "427005,,473365", "add 245"
count = count + 1
call assertEq (Oct("676643,,625127") - Oct("530141,,646236"))~string, "146501,,756671", "sub 245"
count = count + 1
call assertEq (Oct("676643,,625127") & Oct("530141,,646236"))~string, "430041,,604026", "and 245"
count = count + 1
call assertEq (Oct("676643,,625127") | Oct("530141,,646236"))~string, "776743,,667337", "or 245"
count = count + 1
call assertEq (Oct("676643,,625127") && Oct("530141,,646236"))~string, "346702,,063311", "xor 245"
count = count + 1
call assertEq Oct("676643,,625127")~shl(33)~string, "700000,,000000", "shl 245"
count = count + 1
call assertEq Oct("676643,,625127")~shr(33)~string, "000000,,000006", "shr 245"
count = count + 1
call assertEq (Oct("302317,,027360") + Oct("052341,,170643"))~string, "354660,,220223", "add 246"
count = count + 1
call assertEq (Oct("302317,,027360") - Oct("052341,,170643"))~string, "227755,,636515", "sub 246"
count = count + 1
call assertEq (Oct("302317,,027360") & Oct("052341,,170643"))~string, "002301,,020240", "and 246"
count = count + 1
call assertEq (Oct("302317,,027360") | Oct("052341,,170643"))~string, "352357,,177763", "or 246"
count = count + 1
call assertEq (Oct("302317,,027360") && Oct("052341,,170643"))~string, "350056,,157523", "xor 246"
count = count + 1
call assertEq Oct("302317,,027360")~shl(4)~string, "046360,,567400", "shl 246"
count = count + 1
call assertEq Oct("302317,,027360")~shr(4)~string, "014114,,741357", "shr 246"
count = count + 1
call assertEq (Oct("237724,,405536") + Oct("245334,,276546"))~string, "505260,,704304", "add 247"
count = count + 1
call assertEq (Oct("237724,,405536") - Oct("245334,,276546"))~string, "772370,,106770", "sub 247"
count = count + 1
call assertEq (Oct("237724,,405536") & Oct("245334,,276546"))~string, "205324,,004506", "and 247"
count = count + 1
call assertEq (Oct("237724,,405536") | Oct("245334,,276546"))~string, "277734,,677576", "or 247"
count = count + 1
call assertEq (Oct("237724,,405536") && Oct("245334,,276546"))~string, "072410,,673070", "xor 247"
count = count + 1
call assertEq Oct("237724,,405536")~shl(30)~string, "360000,,000000", "shl 247"
count = count + 1
call assertEq Oct("237724,,405536")~shr(30)~string, "000000,,000023", "shr 247"
count = count + 1
call assertEq (Oct("311065,,640010") + Oct("564715,,470274"))~string, "076003,,330304", "add 248"
count = count + 1
call assertEq (Oct("311065,,640010") - Oct("564715,,470274"))~string, "524150,,147514", "sub 248"
count = count + 1
call assertEq (Oct("311065,,640010") & Oct("564715,,470274"))~string, "100005,,440010", "and 248"
count = count + 1
call assertEq (Oct("311065,,640010") | Oct("564715,,470274"))~string, "775775,,670274", "or 248"
count = count + 1
call assertEq (Oct("311065,,640010") && Oct("564715,,470274"))~string, "675770,,230264", "xor 248"
count = count + 1
call assertEq Oct("311065,,640010")~shl(26)~string, "004000,,000000", "shl 248"
count = count + 1
call assertEq Oct("311065,,640010")~shr(26)~string, "000000,,000622", "shr 248"
count = count + 1
call assertEq (Oct("217740,,173502") + Oct("507762,,456202"))~string, "727722,,651704", "add 249"
count = count + 1
call assertEq (Oct("217740,,173502") - Oct("507762,,456202"))~string, "507755,,515300", "sub 249"
count = count + 1
call assertEq (Oct("217740,,173502") & Oct("507762,,456202"))~string, "007740,,052002", "and 249"
count = count + 1
call assertEq (Oct("217740,,173502") | Oct("507762,,456202"))~string, "717762,,577702", "or 249"
count = count + 1
call assertEq (Oct("217740,,173502") && Oct("507762,,456202"))~string, "710022,,525700", "xor 249"
count = count + 1
call assertEq Oct("217740,,173502")~shl(24)~string, "350200,,000000", "shl 249"
count = count + 1
call assertEq Oct("217740,,173502")~shr(24)~string, "000000,,002177", "shr 249"
count = count + 1
call assertEq (Oct("353555,,447005") + Oct("666262,,510012"))~string, "242040,,157017", "add 250"
count = count + 1
call assertEq (Oct("353555,,447005") - Oct("666262,,510012"))~string, "465272,,736773", "sub 250"
count = count + 1
call assertEq (Oct("353555,,447005") & Oct("666262,,510012"))~string, "242040,,400000", "and 250"
count = count + 1
call assertEq (Oct("353555,,447005") | Oct("666262,,510012"))~string, "777777,,557017", "or 250"
count = count + 1
call assertEq (Oct("353555,,447005") && Oct("666262,,510012"))~string, "535737,,157017", "xor 250"
count = count + 1
call assertEq Oct("353555,,447005")~shl(28)~string, "012000,,000000", "shl 250"
count = count + 1
call assertEq Oct("353555,,447005")~shr(28)~string, "000000,,000165", "shr 250"
count = count + 1
call assertEq (Oct("246057,,722145") + Oct("372347,,106331"))~string, "640427,,030476", "add 251"
count = count + 1
call assertEq (Oct("246057,,722145") - Oct("372347,,106331"))~string, "653510,,613614", "sub 251"
count = count + 1
call assertEq (Oct("246057,,722145") & Oct("372347,,106331"))~string, "242047,,102101", "and 251"
count = count + 1
call assertEq (Oct("246057,,722145") | Oct("372347,,106331"))~string, "376357,,726375", "or 251"
count = count + 1
call assertEq (Oct("246057,,722145") && Oct("372347,,106331"))~string, "134310,,624274", "xor 251"
count = count + 1
call assertEq Oct("246057,,722145")~shl(1)~string, "514137,,644312", "shl 251"
count = count + 1
call assertEq Oct("246057,,722145")~shr(1)~string, "123027,,751062", "shr 251"
count = count + 1
call assertEq (Oct("462625,,074375") + Oct("612725,,724430"))~string, "275553,,021025", "add 252"
count = count + 1
call assertEq (Oct("462625,,074375") - Oct("612725,,724430"))~string, "647677,,147745", "sub 252"
count = count + 1
call assertEq (Oct("462625,,074375") & Oct("612725,,724430"))~string, "402625,,024030", "and 252"
count = count + 1
call assertEq (Oct("462625,,074375") | Oct("612725,,724430"))~string, "672725,,774775", "or 252"
count = count + 1
call assertEq (Oct("462625,,074375") && Oct("612725,,724430"))~string, "270100,,750745", "xor 252"
count = count + 1
call assertEq Oct("462625,,074375")~shl(34)~string, "200000,,000000", "shl 252"
count = count + 1
call assertEq Oct("462625,,074375")~shr(34)~string, "000000,,000002", "shr 252"
count = count + 1
call assertEq (Oct("162104,,720215") + Oct("620336,,457776"))~string, "002443,,400213", "add 253"
count = count + 1
call assertEq (Oct("162104,,720215") - Oct("620336,,457776"))~string, "341546,,240217", "sub 253"
count = count + 1
call assertEq (Oct("162104,,720215") & Oct("620336,,457776"))~string, "020104,,400214", "and 253"
count = count + 1
call assertEq (Oct("162104,,720215") | Oct("620336,,457776"))~string, "762336,,777777", "or 253"
count = count + 1
call assertEq (Oct("162104,,720215") && Oct("620336,,457776"))~string, "742232,,377563", "xor 253"
count = count + 1
call assertEq Oct("162104,,720215")~shl(1)~string, "344211,,640432", "shl 253"
count = count + 1
call assertEq Oct("162104,,720215")~shr(1)~string, "071042,,350106", "shr 253"
count = count + 1
call assertEq (Oct("546324,,006445") + Oct("664757,,713465"))~string, "433303,,722132", "add 254"
count = count + 1
call assertEq (Oct("546324,,006445") - Oct("664757,,713465"))~string, "661344,,072760", "sub 254"
count = count + 1
call assertEq (Oct("546324,,006445") & Oct("664757,,713465"))~string, "444304,,002445", "and 254"
count = count + 1
call assertEq (Oct("546324,,006445") | Oct("664757,,713465"))~string, "766777,,717465", "or 254"
count = count + 1
call assertEq (Oct("546324,,006445") && Oct("664757,,713465"))~string, "322473,,715020", "xor 254"
count = count + 1
call assertEq Oct("546324,,006445")~shl(17)~string, "003222,,400000", "shl 254"
count = count + 1
call assertEq Oct("546324,,006445")~shr(17)~string, "000001,,314650", "shr 254"
count = count + 1
call assertEq (Oct("617365,,413657") + Oct("611630,,221334"))~string, "431215,,635213", "add 255"
count = count + 1
call assertEq (Oct("617365,,413657") - Oct("611630,,221334"))~string, "005535,,172323", "sub 255"
count = count + 1
call assertEq (Oct("617365,,413657") & Oct("611630,,221334"))~string, "611220,,001214", "and 255"
count = count + 1
call assertEq (Oct("617365,,413657") | Oct("611630,,221334"))~string, "617775,,633777", "or 255"
count = count + 1
call assertEq (Oct("617365,,413657") && Oct("611630,,221334"))~string, "006555,,632563", "xor 255"
count = count + 1
call assertEq Oct("617365,,413657")~shl(3)~string, "173654,,136570", "shl 255"
count = count + 1
call assertEq Oct("617365,,413657")~shr(3)~string, "061736,,541365", "shr 255"
count = count + 1
call assertEq (Oct("017720,,153617") + Oct("005577,,221045"))~string, "025517,,374664", "add 256"
count = count + 1
call assertEq (Oct("017720,,153617") - Oct("005577,,221045"))~string, "012120,,732552", "sub 256"
count = count + 1
call assertEq (Oct("017720,,153617") & Oct("005577,,221045"))~string, "005520,,001005", "and 256"
count = count + 1
call assertEq (Oct("017720,,153617") | Oct("005577,,221045"))~string, "017777,,373657", "or 256"
count = count + 1
call assertEq (Oct("017720,,153617") && Oct("005577,,221045"))~string, "012257,,372652", "xor 256"
count = count + 1
call assertEq Oct("017720,,153617")~shl(26)~string, "707400,,000000", "shl 256"
count = count + 1
call assertEq Oct("017720,,153617")~shr(26)~string, "000000,,000037", "shr 256"
count = count + 1
call assertEq (Oct("776661,,503702") + Oct("263065,,177757"))~string, "261746,,703661", "add 257"
count = count + 1
call assertEq (Oct("776661,,503702") - Oct("263065,,177757"))~string, "513574,,303723", "sub 257"
count = count + 1
call assertEq (Oct("776661,,503702") & Oct("263065,,177757"))~string, "262061,,103702", "and 257"
count = count + 1
call assertEq (Oct("776661,,503702") | Oct("263065,,177757"))~string, "777665,,577757", "or 257"
count = count + 1
call assertEq (Oct("776661,,503702") && Oct("263065,,177757"))~string, "515604,,474055", "xor 257"
count = count + 1
call assertEq Oct("776661,,503702")~shl(7)~string, "554320,,760400", "shl 257"
count = count + 1
call assertEq Oct("776661,,503702")~shr(7)~string, "003773,,306417", "shr 257"
count = count + 1
call assertEq (\Oct("353063,,360614"))~string, "424714,,417163", "not 0"
count=count+1
call assertEq (-Oct("353063,,360614"))~string, "424714,,417164", "neg 0"
count=count+1
call assertEq (\Oct("350672,,532046"))~string, "427105,,245731", "not 1"
count=count+1
call assertEq (-Oct("350672,,532046"))~string, "427105,,245732", "neg 1"
count=count+1
call assertEq (\Oct("726275,,505765"))~string, "051502,,272012", "not 2"
count=count+1
call assertEq (-Oct("726275,,505765"))~string, "051502,,272013", "neg 2"
count=count+1
call assertEq (\Oct("652664,,624377"))~string, "125113,,153400", "not 3"
count=count+1
call assertEq (-Oct("652664,,624377"))~string, "125113,,153401", "neg 3"
count=count+1
call assertEq (\Oct("606060,,145105"))~string, "171717,,632672", "not 4"
count=count+1
call assertEq (-Oct("606060,,145105"))~string, "171717,,632673", "neg 4"
count=count+1
call assertEq (\Oct("651722,,541474"))~string, "126055,,236303", "not 5"
count=count+1
call assertEq (-Oct("651722,,541474"))~string, "126055,,236304", "neg 5"
count=count+1
call assertEq (\Oct("135246,,571527"))~string, "642531,,206250", "not 6"
count=count+1
call assertEq (-Oct("135246,,571527"))~string, "642531,,206251", "neg 6"
count=count+1
call assertEq (\Oct("145555,,010664"))~string, "632222,,767113", "not 7"
count=count+1
call assertEq (-Oct("145555,,010664"))~string, "632222,,767114", "neg 7"
count=count+1
call assertEq (\Oct("223225,,412111"))~string, "554552,,365666", "not 8"
count=count+1
call assertEq (-Oct("223225,,412111"))~string, "554552,,365667", "neg 8"
count=count+1
call assertEq (\Oct("247276,,522332"))~string, "530501,,255445", "not 9"
count=count+1
call assertEq (-Oct("247276,,522332"))~string, "530501,,255446", "neg 9"
count=count+1
call assertEq (\Oct("041356,,162227"))~string, "736421,,615550", "not 10"
count=count+1
call assertEq (-Oct("041356,,162227"))~string, "736421,,615551", "neg 10"
count=count+1
call assertEq (\Oct("566524,,677202"))~string, "211253,,100575", "not 11"
count=count+1
call assertEq (-Oct("566524,,677202"))~string, "211253,,100576", "neg 11"
count=count+1
call assertEq (\Oct("743440,,117405"))~string, "034337,,660372", "not 12"
count=count+1
call assertEq (-Oct("743440,,117405"))~string, "034337,,660373", "neg 12"
count=count+1
call assertEq (\Oct("330266,,432120"))~string, "447511,,345657", "not 13"
count=count+1
call assertEq (-Oct("330266,,432120"))~string, "447511,,345660", "neg 13"
count=count+1
call assertEq (\Oct("361614,,144277"))~string, "416163,,633500", "not 14"
count=count+1
call assertEq (-Oct("361614,,144277"))~string, "416163,,633501", "neg 14"
count=count+1
call assertEq (\Oct("721370,,205667"))~string, "056407,,572110", "not 15"
count=count+1
call assertEq (-Oct("721370,,205667"))~string, "056407,,572111", "neg 15"
count=count+1
call assertEq (\Oct("721260,,272032"))~string, "056517,,505745", "not 16"
count=count+1
call assertEq (-Oct("721260,,272032"))~string, "056517,,505746", "neg 16"
count=count+1
call assertEq (\Oct("611302,,142175"))~string, "166475,,635602", "not 17"
count=count+1
call assertEq (-Oct("611302,,142175"))~string, "166475,,635603", "neg 17"
count=count+1
call assertEq (\Oct("476414,,757267"))~string, "301363,,020510", "not 18"
count=count+1
call assertEq (-Oct("476414,,757267"))~string, "301363,,020511", "neg 18"
count=count+1
call assertEq (\Oct("517536,,262562"))~string, "260241,,515215", "not 19"
count=count+1
call assertEq (-Oct("517536,,262562"))~string, "260241,,515216", "neg 19"
count=count+1
call assertEq (\Oct("733156,,041602"))~string, "044621,,736175", "not 20"
count=count+1
call assertEq (-Oct("733156,,041602"))~string, "044621,,736176", "neg 20"
count=count+1
call assertEq (\Oct("214671,,536512"))~string, "563106,,241265", "not 21"
count=count+1
call assertEq (-Oct("214671,,536512"))~string, "563106,,241266", "neg 21"
count=count+1
call assertEq (\Oct("427027,,106074"))~string, "350750,,671703", "not 22"
count=count+1
call assertEq (-Oct("427027,,106074"))~string, "350750,,671704", "neg 22"
count=count+1
call assertEq (\Oct("303224,,242065"))~string, "474553,,535712", "not 23"
count=count+1
call assertEq (-Oct("303224,,242065"))~string, "474553,,535713", "neg 23"
count=count+1
call assertEq (\Oct("011133,,041501"))~string, "766644,,736276", "not 24"
count=count+1
call assertEq (-Oct("011133,,041501"))~string, "766644,,736277", "neg 24"
count=count+1
call assertEq (\Oct("573751,,676610"))~string, "204026,,101167", "not 25"
count=count+1
call assertEq (-Oct("573751,,676610"))~string, "204026,,101170", "neg 25"
count=count+1
call assertEq (\Oct("763571,,066642"))~string, "014206,,711135", "not 26"
count=count+1
call assertEq (-Oct("763571,,066642"))~string, "014206,,711136", "neg 26"
count=count+1
call assertEq (\Oct("223670,,027473"))~string, "554107,,750304", "not 27"
count=count+1
call assertEq (-Oct("223670,,027473"))~string, "554107,,750305", "neg 27"
count=count+1
call assertEq (\Oct("426332,,327424"))~string, "351445,,450353", "not 28"
count=count+1
call assertEq (-Oct("426332,,327424"))~string, "351445,,450354", "neg 28"
count=count+1
call assertEq (\Oct("722007,,221763"))~string, "055770,,556014", "not 29"
count=count+1
call assertEq (-Oct("722007,,221763"))~string, "055770,,556015", "neg 29"
count=count+1
call assertEq (\Oct("017006,,054741"))~string, "760771,,723036", "not 30"
count=count+1
call assertEq (-Oct("017006,,054741"))~string, "760771,,723037", "neg 30"
count=count+1
call assertEq (\Oct("054555,,627602"))~string, "723222,,150175", "not 31"
count=count+1
call assertEq (-Oct("054555,,627602"))~string, "723222,,150176", "neg 31"
count=count+1
call assertEq (\Oct("142716,,442414"))~string, "635061,,335363", "not 32"
count=count+1
call assertEq (-Oct("142716,,442414"))~string, "635061,,335364", "neg 32"
count=count+1
call assertEq (\Oct("360762,,505455"))~string, "417015,,272322", "not 33"
count=count+1
call assertEq (-Oct("360762,,505455"))~string, "417015,,272323", "neg 33"
count=count+1
call assertEq (\Oct("050256,,655526"))~string, "727521,,122251", "not 34"
count=count+1
call assertEq (-Oct("050256,,655526"))~string, "727521,,122252", "neg 34"
count=count+1
call assertEq (\Oct("461557,,372505"))~string, "316220,,405272", "not 35"
count=count+1
call assertEq (-Oct("461557,,372505"))~string, "316220,,405273", "neg 35"
count=count+1
call assertEq (\Oct("037643,,362200"))~string, "740134,,415577", "not 36"
count=count+1
call assertEq (-Oct("037643,,362200"))~string, "740134,,415600", "neg 36"
count=count+1
call assertEq (\Oct("101331,,625305"))~string, "676446,,152472", "not 37"
count=count+1
call assertEq (-Oct("101331,,625305"))~string, "676446,,152473", "neg 37"
count=count+1
call assertEq (\Oct("573502,,552671"))~string, "204275,,225106", "not 38"
count=count+1
call assertEq (-Oct("573502,,552671"))~string, "204275,,225107", "neg 38"
count=count+1
call assertEq (\Oct("766325,,347316"))~string, "011452,,430461", "not 39"
count=count+1
call assertEq (-Oct("766325,,347316"))~string, "011452,,430462", "neg 39"
count=count+1
call assertEq (\Oct("632043,,417351"))~string, "145734,,360426", "not 40"
count=count+1
call assertEq (-Oct("632043,,417351"))~string, "145734,,360427", "neg 40"
count=count+1
call assertEq (\Oct("244272,,625353"))~string, "533505,,152424", "not 41"
count=count+1
call assertEq (-Oct("244272,,625353"))~string, "533505,,152425", "neg 41"
count=count+1
call assertEq (\Oct("563367,,171446"))~string, "214410,,606331", "not 42"
count=count+1
call assertEq (-Oct("563367,,171446"))~string, "214410,,606332", "neg 42"
count=count+1
call assertEq (\Oct("356260,,702566"))~string, "421517,,075211", "not 43"
count=count+1
call assertEq (-Oct("356260,,702566"))~string, "421517,,075212", "neg 43"
count=count+1
call assertEq (\Oct("424315,,624373"))~string, "353462,,153404", "not 44"
count=count+1
call assertEq (-Oct("424315,,624373"))~string, "353462,,153405", "neg 44"
count=count+1
call assertEq (\Oct("265020,,640075"))~string, "512757,,137702", "not 45"
count=count+1
call assertEq (-Oct("265020,,640075"))~string, "512757,,137703", "neg 45"
count=count+1
call assertEq (\Oct("343251,,362311"))~string, "434526,,415466", "not 46"
count=count+1
call assertEq (-Oct("343251,,362311"))~string, "434526,,415467", "neg 46"
count=count+1
call assertEq (\Oct("527436,,747036"))~string, "250341,,030741", "not 47"
count=count+1
call assertEq (-Oct("527436,,747036"))~string, "250341,,030742", "neg 47"
count=count+1
call assertEq (\Oct("113127,,677622"))~string, "664650,,100155", "not 48"
count=count+1
call assertEq (-Oct("113127,,677622"))~string, "664650,,100156", "neg 48"
count=count+1
call assertEq (\Oct("671716,,171307"))~string, "106061,,606470", "not 49"
count=count+1
call assertEq (-Oct("671716,,171307"))~string, "106061,,606471", "neg 49"
count=count+1
call assertEq (\Oct("027005,,664024"))~string, "750772,,113753", "not 50"
count=count+1
call assertEq (-Oct("027005,,664024"))~string, "750772,,113754", "neg 50"
count=count+1
call assertEq (\Oct("723470,,027567"))~string, "054307,,750210", "not 51"
count=count+1
call assertEq (-Oct("723470,,027567"))~string, "054307,,750211", "neg 51"
count=count+1
call assertEq (\Oct("044524,,756765"))~string, "733253,,021012", "not 52"
count=count+1
call assertEq (-Oct("044524,,756765"))~string, "733253,,021013", "neg 52"
count=count+1
call assertEq (\Oct("006450,,143352"))~string, "771327,,634425", "not 53"
count=count+1
call assertEq (-Oct("006450,,143352"))~string, "771327,,634426", "neg 53"
count=count+1
call assertEq (\Oct("376663,,062631"))~string, "401114,,715146", "not 54"
count=count+1
call assertEq (-Oct("376663,,062631"))~string, "401114,,715147", "neg 54"
count=count+1
call assertEq (\Oct("461760,,416416"))~string, "316017,,361361", "not 55"
count=count+1
call assertEq (-Oct("461760,,416416"))~string, "316017,,361362", "neg 55"
count=count+1
call assertEq (\Oct("513607,,546502"))~string, "264170,,231275", "not 56"
count=count+1
call assertEq (-Oct("513607,,546502"))~string, "264170,,231276", "neg 56"
count=count+1
call assertEq (\Oct("031326,,713352"))~string, "746451,,064425", "not 57"
count=count+1
call assertEq (-Oct("031326,,713352"))~string, "746451,,064426", "neg 57"
count=count+1
call assertEq (\Oct("441044,,714662"))~string, "336733,,063115", "not 58"
count=count+1
call assertEq (-Oct("441044,,714662"))~string, "336733,,063116", "neg 58"
count=count+1
call assertEq (\Oct("567324,,574613"))~string, "210453,,203164", "not 59"
count=count+1
call assertEq (-Oct("567324,,574613"))~string, "210453,,203165", "neg 59"
count=count+1
call assertEq (\Oct("344500,,161725"))~string, "433277,,616052", "not 60"
count=count+1
call assertEq (-Oct("344500,,161725"))~string, "433277,,616053", "neg 60"
count=count+1
call assertEq (\Oct("001752,,177635"))~string, "776025,,600142", "not 61"
count=count+1
call assertEq (-Oct("001752,,177635"))~string, "776025,,600143", "neg 61"
count=count+1
call assertEq (\Oct("574174,,333324"))~string, "203603,,444453", "not 62"
count=count+1
call assertEq (-Oct("574174,,333324"))~string, "203603,,444454", "neg 62"
count=count+1
call assertEq (\Oct("723634,,001311"))~string, "054143,,776466", "not 63"
count=count+1
call assertEq (-Oct("723634,,001311"))~string, "054143,,776467", "neg 63"
count=count+1
call assertEq (\Oct("155706,,771337"))~string, "622071,,006440", "not 64"
count=count+1
call assertEq (-Oct("155706,,771337"))~string, "622071,,006441", "neg 64"
count=count+1
call assertEq (\Oct("430002,,613416"))~string, "347775,,164361", "not 65"
count=count+1
call assertEq (-Oct("430002,,613416"))~string, "347775,,164362", "neg 65"
count=count+1
call assertEq (\Oct("021061,,474011"))~string, "756716,,303766", "not 66"
count=count+1
call assertEq (-Oct("021061,,474011"))~string, "756716,,303767", "neg 66"
count=count+1
call assertEq (\Oct("407026,,065217"))~string, "370751,,712560", "not 67"
count=count+1
call assertEq (-Oct("407026,,065217"))~string, "370751,,712561", "neg 67"
count=count+1
call assertEq (\Oct("476041,,536714"))~string, "301736,,241063", "not 68"
count=count+1
call assertEq (-Oct("476041,,536714"))~string, "301736,,241064", "neg 68"
count=count+1
call assertEq (\Oct("712525,,563253"))~string, "065252,,214524", "not 69"
count=count+1
call assertEq (-Oct("712525,,563253"))~string, "065252,,214525", "neg 69"
count=count+1
call assertEq (\Oct("156465,,146421"))~string, "621312,,631356", "not 70"
count=count+1
call assertEq (-Oct("156465,,146421"))~string, "621312,,631357", "neg 70"
count=count+1
call assertEq (\Oct("321566,,017315"))~string, "456211,,760462", "not 71"
count=count+1
call assertEq (-Oct("321566,,017315"))~string, "456211,,760463", "neg 71"
count=count+1
call assertEq (\Oct("773627,,614373"))~string, "004150,,163404", "not 72"
count=count+1
call assertEq (-Oct("773627,,614373"))~string, "004150,,163405", "neg 72"
count=count+1
call assertEq (\Oct("747510,,777604"))~string, "030267,,000173", "not 73"
count=count+1
call assertEq (-Oct("747510,,777604"))~string, "030267,,000174", "neg 73"
count=count+1
call assertEq (\Oct("032337,,312726"))~string, "745440,,465051", "not 74"
count=count+1
call assertEq (-Oct("032337,,312726"))~string, "745440,,465052", "neg 74"
count=count+1
call assertEq (\Oct("737467,,056505"))~string, "040310,,721272", "not 75"
count=count+1
call assertEq (-Oct("737467,,056505"))~string, "040310,,721273", "neg 75"
count=count+1
call assertEq (\Oct("040416,,162015"))~string, "737361,,615762", "not 76"
count=count+1
call assertEq (-Oct("040416,,162015"))~string, "737361,,615763", "neg 76"
count=count+1
call assertEq (\Oct("105574,,345105"))~string, "672203,,432672", "not 77"
count=count+1
call assertEq (-Oct("105574,,345105"))~string, "672203,,432673", "neg 77"
count=count+1
call assertEq (\Oct("734037,,312770"))~string, "043740,,465007", "not 78"
count=count+1
call assertEq (-Oct("734037,,312770"))~string, "043740,,465010", "neg 78"
count=count+1
call assertEq (\Oct("320625,,577110"))~string, "457152,,200667", "not 79"
count=count+1
call assertEq (-Oct("320625,,577110"))~string, "457152,,200670", "neg 79"
count=count+1
call assertEq (\Oct("064127,,563242"))~string, "713650,,214535", "not 80"
count=count+1
call assertEq (-Oct("064127,,563242"))~string, "713650,,214536", "neg 80"
count=count+1
call assertEq (\Oct("214641,,406770"))~string, "563136,,371007", "not 81"
count=count+1
call assertEq (-Oct("214641,,406770"))~string, "563136,,371010", "neg 81"
count=count+1
call assertEq (\Oct("577561,,307152"))~string, "200216,,470625", "not 82"
count=count+1
call assertEq (-Oct("577561,,307152"))~string, "200216,,470626", "neg 82"
count=count+1
call assertEq (\Oct("075224,,562530"))~string, "702553,,215247", "not 83"
count=count+1
call assertEq (-Oct("075224,,562530"))~string, "702553,,215250", "neg 83"
count=count+1
call assertEq (\Oct("544057,,535540"))~string, "233720,,242237", "not 84"
count=count+1
call assertEq (-Oct("544057,,535540"))~string, "233720,,242240", "neg 84"
count=count+1
call assertEq (\Oct("156703,,570137"))~string, "621074,,207640", "not 85"
count=count+1
call assertEq (-Oct("156703,,570137"))~string, "621074,,207641", "neg 85"
count=count+1
call assertEq (\Oct("640752,,371334"))~string, "137025,,406443", "not 86"
count=count+1
call assertEq (-Oct("640752,,371334"))~string, "137025,,406444", "neg 86"
count=count+1
call assertEq (\Oct("212713,,007462"))~string, "565064,,770315", "not 87"
count=count+1
call assertEq (-Oct("212713,,007462"))~string, "565064,,770316", "neg 87"
count=count+1
call assertEq (\Oct("677445,,147303"))~string, "100332,,630474", "not 88"
count=count+1
call assertEq (-Oct("677445,,147303"))~string, "100332,,630475", "neg 88"
count=count+1
call assertEq (\Oct("630450,,332566"))~string, "147327,,445211", "not 89"
count=count+1
call assertEq (-Oct("630450,,332566"))~string, "147327,,445212", "neg 89"
count=count+1
call assertEq (\Oct("712556,,431564"))~string, "065221,,346213", "not 90"
count=count+1
call assertEq (-Oct("712556,,431564"))~string, "065221,,346214", "neg 90"
count=count+1
call assertEq (\Oct("677734,,044263"))~string, "100043,,733514", "not 91"
count=count+1
call assertEq (-Oct("677734,,044263"))~string, "100043,,733515", "neg 91"
count=count+1
call assertEq (\Oct("361423,,561300"))~string, "416354,,216477", "not 92"
count=count+1
call assertEq (-Oct("361423,,561300"))~string, "416354,,216500", "neg 92"
count=count+1
call assertEq (\Oct("443064,,263357"))~string, "334713,,514420", "not 93"
count=count+1
call assertEq (-Oct("443064,,263357"))~string, "334713,,514421", "neg 93"
count=count+1
call assertEq (\Oct("652777,,245101"))~string, "125000,,532676", "not 94"
count=count+1
call assertEq (-Oct("652777,,245101"))~string, "125000,,532677", "neg 94"
count=count+1
call assertEq (\Oct("741302,,120050"))~string, "036475,,657727", "not 95"
count=count+1
call assertEq (-Oct("741302,,120050"))~string, "036475,,657730", "neg 95"
count=count+1
call assertEq (\Oct("054417,,373334"))~string, "723360,,404443", "not 96"
count=count+1
call assertEq (-Oct("054417,,373334"))~string, "723360,,404444", "neg 96"
count=count+1
call assertEq (\Oct("611162,,703605"))~string, "166615,,074172", "not 97"
count=count+1
call assertEq (-Oct("611162,,703605"))~string, "166615,,074173", "neg 97"
count=count+1
call assertEq (\Oct("771653,,167215"))~string, "006124,,610562", "not 98"
count=count+1
call assertEq (-Oct("771653,,167215"))~string, "006124,,610563", "neg 98"
count=count+1
call assertEq (\Oct("504106,,506252"))~string, "273671,,271525", "not 99"
count=count+1
call assertEq (-Oct("504106,,506252"))~string, "273671,,271526", "neg 99"
count=count+1
say "LROct randomized oracle acceptance: PASS" count "operator cases"
exit 0

assertEq: procedure
  use arg actual, expected, label
  if actual \= expected then do
    say "FAIL" label "expected" expected "got" actual
    exit 1
  end
  return 1

assertBool: procedure
  use arg actual, expected, label
  if actual \= expected then do
    say "FAIL" label "expected" expected "got" actual
    exit 1
  end
  return 1

::requires "../lib/OctalBits.cls"
