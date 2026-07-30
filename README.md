# Testbed DTNEX — Vagrant + Ansible

Ambiente di test multi-nodo per [DTNEX](https://github.com/samograsic/ion-dtn-dtnex),
il meccanismo di distribuzione automatica della topologia per reti DTN.

Ogni VM ospita la propria istanza di ION e la propria istanza di DTNEX.
Il numero di nodi è parametrizzabile e **l'avvio dei servizi è manuale**:
il provisioning si limita a compilare, installare e configurare.

---

## Prerequisiti sull'host

| Componente | Versione minima | Note |
|---|---|---|
| Vagrant | 2.2 | |
| VirtualBox | 6.1 | supportato anche libvirt |
| Ansible | 2.12 | `ansible-playbook` deve essere nel PATH dell'host |

Servono circa 2 GB di RAM e 2 vCPU per nodo, più ~4 GB di disco per VM.

---

## Sorgenti: locali o da git

Per default (`ion_source_mode: local` / `dtnex_source_mode: local` in
`group_vars/all.yml`) **nessun nodo scarica nulla da internet**: sorgenti
(e, se presenti, binari già compilati) vengono presi dalla cartella
`vendor/` del progetto, montata dentro ogni VM.

Prima del primo `vagrant up`, popola `vendor/` con quello che hai già in
locale — vedi **[vendor/README.md](vendor/README.md)** per la struttura
esatta e degli esempi di comandi `cp`. In breve:

```
vendor/
├── ion-src/            sorgenti di ION o IONe
├── dtnex-src/          sorgenti di ion-dtn-dtnex
└── prebuilt/           opzionale: binari/librerie gia' compilati,
    ├── ion/            per saltare del tutto la fase di build
    └── dtnex/
```

Se preferisci invece scaricare da git (repository e versioni già
configurati in `group_vars/all.yml`), imposta:

```yaml
ion_source_mode:   git
dtnex_source_mode: git
```

I binari precompilati vengono usati automaticamente solo se risultano
eseguibili sulla VM (verifica con `file`/`ldd`); altrimenti si ricompila da
sorgente senza intervento manuale.

---

## Avvio rapido

```bash
# tre nodi in catena (default)
vagrant up

# due nodi
NODES=2 vagrant up

# tre nodi a mesh completa
NODES=3 TOPOLOGY=full vagrant up
```

Se si compila da sorgente, la prima esecuzione richiede 15–25 minuti per
nodo. Le esecuzioni successive di `vagrant provision` sono rapide, perché
un file marker (`/usr/local/share/ion-testbed-installed`) evita la
ricompilazione a meno di modifiche ai sorgenti locali o `*_force_rebuild: true`.

Al termine il provisioning **non avvia nulla**. Per portare su un nodo:

```bash
vagrant ssh dtn-node1
cd ~/dtn
./start-ion.sh        # avvia ION e stampa contact plan ed egress plan
./start-dtnex.sh      # DTNEX in foreground, output di debug
# oppure
./start-dtnex.sh -d   # in background, log in ~/dtn/log/dtnex.log
```

Ripeti su ogni nodo.

---

## Parametrizzazione

I default stanno in `config.yml` e sono sovrascrivibili da variabili d'ambiente:

| Variabile | `config.yml` | Default | Significato |
|---|---|---|---|
| `NODES` | `nodes` | 3 | numero di VM (2 … `max_nodes`) |
| `TOPOLOGY` | `topology` | `chain` | `chain`, `full`, `ring` |

Altri parametri utili in `config.yml`: `box`, `memory`, `cpus`,
`network_prefix`, `ip_start`, `ipn_base`.

I parametri applicativi (provenienza dei sorgenti, versioni di ION e DTNEX,
memoria SDR, porte LTP/TCP, intervalli di DTNEX, chiave HMAC) stanno in
`group_vars/all.yml`.

### Schema di indirizzamento

Il nodo *i* riceve:

- hostname `dtn-node<i>`
- IP `192.168.56.<20+i>`
- node number IPN `268485000 + i`

Con 3 nodi: `dtn-node1` = `ipn:268485001` @ `192.168.56.21`, e così via.
Tutti i nodi sono risolvibili per nome via `/etc/hosts`.

### Topologie

```
chain (default)      full                  ring (n >= 4)
n1 — n2 — n3         n1 — n2               n1 — n2
                       \  /                 |     |
                        n3                 n4 — n3
```

`chain` è la topologia interessante: `n1` e `n3` **non** hanno un link diretto
e nessuno dei due ha `n3`/`n1` nel proprio contact plan iniziale. Se dopo
qualche ciclo di DTNEX il contatto compare, il flooding epidemico multi-hop
sta funzionando. Con `full` questo test non è possibile perché la topologia è
già interamente configurata a mano.

---

## Convergence layer: LTP + TCP

Ogni nodo usa due convergence layer diversi a seconda della destinazione:

- **Loopback (nodo verso se stesso): LTP su UDP.** È il pattern standard ION
  per la consegna locale (vedi `configs/loopback-ltp/` nei sorgenti ION),
  con segmentazione/ritrasmissione gestite da LTP anche se qui il link è
  affidabile per definizione.
- **Vicini diretti (link fra VM): TCP diretto**, sulla rete privata
  Vagrant/VirtualBox.

Questa combinazione replica la logica di un deployment reale in cui LTP si
usa per i link co-locati/a bassa latenza e TCP per i link su IP reale fra
macchine distinte — con la differenza che qui *ogni* vicino è su una VM
diversa, quindi *ogni* link fra vicini passa da TCP.

Porte usate (configurabili in `group_vars/all.yml`):

| Parametro | Default | Uso |
|---|---|---|
| `ion_ltp_port` | 1113 | link service LTP (`udplso`/`udplsi`), solo loopback |
| `ion_tcp_port` | 4556 | CLA TCP fra vicini |

Se preferisci LTP anche fra le VM (non solo in loopback), è un'estensione
possibile ma non inclusa di default: richiede uno span LTP e una porta
dedicata per ciascun vicino diretto invece di un singolo induct TCP condiviso.

---

## Struttura del progetto

```
dtnex-testbed/
├── Vagrantfile              # calcola nodi, IP, IPN e vicini; lancia Ansible
├── config.yml               # parametri del testbed
├── ansible.cfg
├── site.yml                 # playbook principale
├── group_vars/all.yml       # versioni, percorsi, parametri ION e DTNEX
├── vendor/                  # sorgenti/binari locali di ION e DTNEX (vedi vendor/README.md)
└── roles/
    ├── common/              # pacchetti, /etc/hosts, sysctl IPC, chrony
    ├── ion/                 # installa ION/IONe: prebuilt -> sorgente locale -> git
    ├── ion_config/          # node.ionconfig, node.rc, script di gestione ION
    ├── dtnex/               # installa DTNEX: prebuilt -> sorgente locale -> git
    └── dtnex_config/        # dtnex.conf, script di gestione DTNEX
```

Il provisioner Ansible è agganciato solo all'ultima VM ma gira con
`--limit=all` e `--forks=<n>`: i ruoli vengono eseguiti su tutti i nodi in
parallelo, così una eventuale build di ION avviene una volta sola in termini
di tempo reale.

---

## File generati su ogni nodo (`~/dtn/`)

| File | Contenuto |
|---|---|
| `node.ionconfig` | dimensioni di working memory e SDR heap (wmKey/sdrName restano ai default di ION: vedi nota sotto) |
| `node.rc` | file combinato per `ionstart -I`: sezioni `ionadmin`, `ionsecadmin`, `ltpadmin`, `bpadmin`, `ipnadmin` |
| `dtnex.conf` | configurazione di DTNEX |
| `start-ion.sh` / `stop-ion.sh` | gestione di ION |
| `start-dtnex.sh` / `stop-dtnex.sh` | gestione di DTNEX |
| `status.sh` | contact plan, range, span LTP, egress plan, bundle in coda, metadati appresi |
| `test-network.sh` | `bping` verso gli altri nodi sull'endpoint echo `.12161` |
| `contactGraph.gv` | grafo GraphViz della topologia, scritto da DTNEX |
| `nodesmetadata.txt` | metadati dei nodi, generato automaticamente da DTNEX (non è un file di input: vedi sotto) |

### Cosa contiene `node.rc`

Solo i contatti verso i **vicini diretti**, più il contatto di loopback.
Questo è deliberato: è il punto dell'esercizio. Tutto il resto della topologia
deve arrivare da DTNEX.

Per il nodo centrale di una catena a 3 (estratto):

```
## begin ionadmin
1 268485002 /home/vagrant/dtn/node.ionconfig
s
a contact +1 +86400 268485002 268485002 100000
a range   +1 +86400 268485002 268485002 1
a contact +1 +86400 268485002 268485001 100000
a contact +1 +86400 268485001 268485002 100000
a range   +1 +86400 268485002 268485001 1
a contact +1 +86400 268485002 268485003 100000
a contact +1 +86400 268485003 268485002 100000
a range   +1 +86400 268485002 268485003 1
m clockerr 1
## end ionadmin

## begin ltpadmin
1 128
a span 268485002 32 32 64000 64000 1 'udplso 127.0.0.1:1113'
s 'udplsi 0.0.0.0:1113'
## end ltpadmin

## begin bpadmin
...
a protocol ltp
a induct ltp 268485002 ltpcli
a outduct ltp 268485002 ltpclo

a protocol tcp
a induct tcp 0.0.0.0:4556 tcpcli
a outduct tcp 192.168.56.21:4556 ''
a outduct tcp 192.168.56.23:4556 ''
s
## end bpadmin

## begin ipnadmin
a plan 268485002 ltp/268485002
a plan 268485001 tcp/192.168.56.21:4556
a plan 268485003 tcp/192.168.56.23:4556
## end ipnadmin
```

Gli endpoint `.12160` (DTNEX) e `.12161` (echo) **non** sono dichiarati:
DTNEX li registra da sé a runtime con `addEndpoint()`.

### Perché `node.ionconfig` non personalizza `wmKey`/`sdrName`

ION, quando gira in modalità singolo-nodo-per-macchina (il caso normale di
ogni VM di questo testbed), **rifiuta qualunque `wmKey`/`sdrName` diverso dal
proprio default** — a meno di impostare la variabile d'ambiente
`ION_NODE_LIST_DIR`, pensata per test multi-nodo su un'unica macchina, che
qui non serve. Per questo il template lascia questi due parametri ai default
di ION e personalizza solo `pathName`, `wmSize` e `heapWords` (che non sono
soggetti a questa restrizione). Questo è stato verificato compilando ION
4.1.3s da sorgente e avviandolo con la configurazione generata dal template.

### `nodesmetadata.txt` non è un file di configurazione

DTNEX lo apre solo in scrittura (mai in lettura): all'avvio legge il campo
`nodemetadata` da `dtnex.conf`, registra se stesso in memoria, e da quel
momento riscrive `nodesmetadata.txt` ogni volta che impara — da sé o dai
vicini — nuovi metadati (a patto che `createGraph=true`). Non va quindi
fornito come file di provisioning: si genera da solo.

---

## Verificare che DTNEX funzioni

Con topologia `chain` a 3 nodi, avvia ION e DTNEX su tutti e tre, poi da
`dtn-node1`:

```bash
cd ~/dtn
./status.sh
```

**Prima** che DTNEX abbia lavorato, il contact plan di `n1` contiene solo
`268485001 ↔ 268485001` e `268485001 ↔ 268485002`.

**Dopo** uno o due cicli di `updateInterval` (30 s), deve comparire anche
`268485002 ↔ 268485003`, appreso via flooding: `n2` lo annuncia a `n1`, che
non aveva alcun modo di conoscerlo dalla propria configurazione.

Conferma end-to-end con l'echo di DTNEX:

```bash
./test-network.sh
# ovvero: bping ipn:268485001.3 -> ipn:268485003.12161
```

Se `n3` risponde, il bundle ha attraversato `n2` usando un contatto che CGR
non avrebbe potuto calcolare senza DTNEX.

Il grafo della topologia appresa:

```bash
dot -Tpng ~/dtn/contactGraph.gv -o /vagrant/topology.png
```

---

## Comandi utili

```bash
# rieseguire solo una parte del provisioning
vagrant provision --provision-with ansible          # tutto
ANSIBLE_ARGS='--tags config' vagrant provision      # solo i file di configurazione

# forzare la ricompilazione dopo aver aggiornato vendor/ion-src o vendor/dtnex-src
vagrant provision --provision-with ansible \
  -- --extra-vars "ion_force_rebuild=true dtnex_force_rebuild=true"

# ispezione a mano
printf 'l contact\nq\n' | ionadmin
printf 'l span\nq\n'    | ltpadmin
printf 'l plan\nq\n'    | ipnadmin
bplist
```

Tag Ansible disponibili: `common`, `ion`, `dtnex`, `build`, `config`.

---

## Nota importante: IONe e non ION

DTNEX non usa solo le API pubbliche del Bundle Protocol: legge e scrive
direttamente le strutture in memoria condivisa di ION (l'albero red-black del
contact index, la lista dei plan, `IonDB`). Il layout di quelle struct deve
corrispondere **esattamente** fra il binario di DTNEX e le librerie di ION.

Confrontando gli header inclusi in `ion-dtn-dtnex/include/ion/` con le release
ufficiali NASA/JPL, non c'è corrispondenza con nessuna di esse:

| Header | Differenza rispetto a ION 4.1.3 |
|---|---|
| `ion.h` | `IonDB` ha in più `regions[2]` e `pwcNotices`; il campo `contacts` è in posizione diversa |
| `rfx.h` | `RFX_NOTE_LEN` è 256 anziché 144; firma diversa per `rfx_contact_state()` |
| `bp.h` | blocco `IrfPassagewaysBlk`, campo `irfTraceRptRequested` |

Il `Makefile` upstream lo conferma: `ION_INCDIR = ../ione-code`. DTNEX è
sviluppato contro **IONe 1.1.0**, il branch sperimentale ospitato su
SourceForge, che è anche l'implementazione usata dalla rete OpenIPN/IPNSIG.

Il testbed installa quindi IONe per default. Con ION ufficiale il binario
compila e linka senza errori — `libbp` e `libici` esportano gli stessi
simboli — ma i campi verrebbero letti a offset sbagliati: un fallimento
silenzioso, difficile da diagnosticare.

Per cambiare implementazione, in `group_vars/all.yml`:

```yaml
ion_flavor: ion              # invece di 'ione'
ion_version: ion-open-source-4.1.3s
```

(Le sezioni `node.rc`/LTP+TCP descritte sopra sono state effettivamente
compilate e avviate contro ION 4.1.3s ufficiale durante lo sviluppo di questo
testbed, per verificarne la correttezza sintattica e funzionale — non solo
contro la documentazione.)

---

## Risoluzione dei problemi

**La build di ION fallisce con errori di duplicate symbol.**
GCC 10+ usa `-fno-common` per default. Il ruolo passa già `-fcommon` via
`ion_extra_cflags`; se il problema persiste prova `ion_make_jobs: 1`, perché
il build system ricorsivo di ION non è sempre parallel-safe.

**`ionstart` fallisce con `Config parms wmKey != default` o `sdrName != default`.**
Qualcosa ha reintrodotto un `wmKey`/`sdrName` personalizzato in
`node.ionconfig`: su una VM a singolo nodo vanno lasciati ai default di ION
(vedi la nota dedicata più sopra).

**`ionstart` fallisce con altri errori di memoria condivisa.**
Quasi sempre residui di un'istanza precedente. Esegui `./stop-ion.sh`, che
chiama `ionstop` e poi `killm`. Se non basta: `ipcs -m` e `ipcrm`.

**DTNEX parte ma non scambia nulla.**
Tre cause tipiche, in ordine di frequenza:

1. `presSharedNetworkKey` diversa fra i nodi. I messaggi con HMAC non valido
   vengono scartati *silenziosamente*. Deve essere identica ovunque.
2. `dtnex` lanciato da una directory diversa da `~/dtn`. Il file di
   configurazione è aperto con percorso relativo (`fopen("dtnex.conf", ...)`);
   fuori da lì DTNEX parte con i default e senza scambio di metadati. Usa
   sempre `start-dtnex.sh`.
3. Clock disallineati oltre `contactTimeTolerance`. Verifica con
   `timedatectl` su ogni nodo; `chrony` è installato e attivo.

**DTNEX si riavvia da solo di continuo.**
È il comportamento previsto quando non trova contatti nel contact graph:
interpreta la situazione come un riavvio di ION e si rigenera via `execv()`.
Controlla che `./start-ion.sh` abbia effettivamente caricato il contact plan
(`printf 'l contact\nq\n' | ionadmin` non deve essere vuoto).

**Un nodo non riceve i bundle.**
Verifica che l'induct TCP sia in ascolto (`ss -tlnp | grep 4556`) e che la
rete host-only sia raggiungibile (`ping dtn-node2`). Ubuntu cloud image non
ha ufw attivo per default, ma vale la pena controllarlo.

**Vendor vuota all'avvio del provisioning.**
Con `ion_source_mode: local` (default) e `vendor/ion-src` (o `dtnex-src`)
vuota, il ruolo fallisce con un messaggio esplicito che rimanda a
`vendor/README.md`. Popola la cartella o passa a `ion_source_mode: git`.

---

## Pulizia

```bash
vagrant destroy -f
```
