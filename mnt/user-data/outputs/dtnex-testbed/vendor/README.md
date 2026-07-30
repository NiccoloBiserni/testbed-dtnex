# vendor/ — sorgenti e binari locali

Questa cartella viene montata dentro **ogni** VM in `/vagrant-vendor` (vedi
`Vagrantfile`). Con `ion_source_mode: local` e `dtnex_source_mode: local`
(i default in `group_vars/all.yml`), i ruoli Ansible prendono da qui tutto
il necessario, senza contattare internet.

```
vendor/
├── ion-src/            sorgenti di ION o IONe (root del repository:
│                       deve contenere configure/configure.ac, Makefile, ...)
├── dtnex-src/           sorgenti di ion-dtn-dtnex (dtnex.c, Makefile,
│                       build_standalone.sh, include/ion/...)
└── prebuilt/            opzionale — binari gia' compilati, per saltare
    ├── ion/             del tutto la fase di build
    │   ├── bin/          ionadmin, bpadmin, ipnadmin, ionstart, ionstop,
    │   │                 killm, bping, bpsink, bpsource, bpecho, ...
    │   ├── lib/          libbp.so*, libici.so* (e le altre lib di ION)
    │   └── include/      header pubblici di ION (opzionale: DTNEX porta
    │                     gia' i propri header in dtnex-src/include/ion)
    └── dtnex/
        └── dtnex         binario dtnex gia' compilato
```

## Come popolarla

Copia dentro **questo** progetto le cartelle che hai già in locale, ad
esempio (adatta i percorsi ai tuoi):

```bash
cd dtnex-testbed/vendor

# sorgenti
cp -a ~/dev/ione-code/.          ion-src/
cp -a ~/dev/ion-dtn-dtnex/.      dtnex-src/

# binari/librerie gia' compilati (facoltativo, ma se presenti hanno la
# precedenza: vedi ion_use_prebuilt / dtnex_use_prebuilt)
cp -a /usr/local/bin/{ionadmin,bpadmin,ipnadmin,ionstart,ionstop,killm,bping,bpsink,bpsource,bpecho} prebuilt/ion/bin/
cp -a /usr/local/lib/libbp* /usr/local/lib/libici* prebuilt/ion/lib/
cp -a /usr/local/bin/dtnex prebuilt/dtnex/
```

Non è necessario ripulire `.git/` o gli oggetti di build: la sincronizzazione
verso il disco della VM (dove poi si compila) esclude automaticamente `.git`,
`*.o` e i binari già prodotti (vedi `roles/ion/tasks/main.yml`).

## Comportamento dei ruoli

Per ogni componente (ION e DTNEX), l'ordine di preferenza è:

1. **`*_use_prebuilt: true`** (default) e i binari in `prebuilt/` esistono
   ed risultano eseguibili sulla VM (verificato con `file` e `ldd`) →
   vengono copiati direttamente, **nessuna build**.
2. Altrimenti, sorgenti sincronizzati da `ion-src/` o `dtnex-src/` verso
   `/usr/local/src/...` dentro la VM e compilati lì (mai *dentro* la
   cartella condivisa: le cartelle condivise VirtualBox non gestiscono bene
   permessi e link simbolici durante una build).

## Attenzione ai binari precompilati

I binari in `prebuilt/` funzionano solo se sono stati compilati per
**Linux x86_64, stessa famiglia di libc** della VM (Ubuntu 22.04, glibc).
Se li hai compilati su macOS, su un Raspberry Pi (ARM), o linkati
staticamente contro una libc diversa, il ruolo se ne accorge (controllo
`file` + `ldd`) e **ricompila automaticamente da sorgente** invece di usarli.

## Se cambi i sorgenti locali dopo il primo `vagrant up`

Il provisioning è idempotente tramite un marker
(`/usr/local/share/ion-testbed-installed`): una volta compilato, non
ricompila più automaticamente. Per forzare la ricompilazione dopo aver
aggiornato `ion-src/` o `dtnex-src/`:

```bash
vagrant provision --provision-with ansible \
  -- --extra-vars "ion_force_rebuild=true dtnex_force_rebuild=true"
```

oppure imposta `ion_force_rebuild: true` / `dtnex_force_rebuild: true` in
`group_vars/all.yml`.

## Se preferisci comunque scaricare da internet

Imposta in `group_vars/all.yml`:

```yaml
ion_source_mode:   git
dtnex_source_mode: git
```

I repository e le versioni restano quelli già definiti (`ione_repo`,
`ion_repo`, `dtnex_repo`, ...); questa cartella viene semplicemente ignorata.
