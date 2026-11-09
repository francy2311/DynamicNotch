
# Dynamic Notch

Dynamic Notch è una utility per macOS che trasforma la notch dei MacBook compatibili in un piccolo centro di controllo interattivo, ispirato al concetto di Dynamic Island.

L’obiettivo è integrare informazioni e controlli utili direttamente attorno alla notch, senza occupare spazio con finestre permanenti.

## Funzionalità

Dynamic Notch include:

- controlli multimediali
- titolo, artista e copertina del brano
- play / pausa
- traccia precedente e successiva
- barra di avanzamento
- controllo volume
- controllo luminosità
- HUD per i tasti hardware
- timer
- clipboard manager
- file shelf
- agenda con eventi del calendario
- informazioni sulla batteria
- supporto multi-monitor
- menu bar
- impostazioni dedicate

## Media

La sezione Media mostra le informazioni del contenuto attualmente in riproduzione.

Sono disponibili:

- copertina
- titolo
- artista
- play / pausa
- precedente
- successivo
- seek della traccia

Dynamic Notch può inoltre mostrare automaticamente i controlli quando cambia la traccia o inizia la riproduzione.

## Volume e luminosità

Dynamic Notch permette di controllare direttamente:

- volume di sistema
- luminosità del display

Quando vengono utilizzati i relativi tasti hardware, la notch può mostrare un HUD dedicato.

## Timer

È possibile avviare rapidamente un timer direttamente dalla notch.

Sono disponibili alcuni preset e un timer personalizzato.

Al termine del timer viene fornito un feedback visivo e sonoro.

## Clipboard

Il Clipboard Manager mantiene una cronologia temporanea degli elementi copiati.

Supporta:

- testo
- file
- cartelle
- copie multiple di file
- rimozione degli elementi
- cancellazione della cronologia
- copia nuovamente con un click

Gli elementi duplicati vengono gestiti automaticamente.

## File Shelf

La File Shelf permette di trascinare temporaneamente file e cartelle dentro Dynamic Notch.

È possibile:

- aggiungere file tramite drag & drop
- aprire un elemento
- mostrarlo nel Finder
- rimuoverlo
- svuotare la shelf
- trascinarlo nuovamente fuori dalla notch

La shelf è temporanea e non modifica i file originali.

## Agenda

Dynamic Notch può mostrare il prossimo evento o l’evento attualmente in corso nel Calendario macOS.

Sono disponibili:

- nome dell’evento
- orario
- calendario di appartenenza
- link per partecipare alle riunioni, quando disponibile
- apertura dell’evento nel Calendario

## Batteria

La sezione Battery mostra rapidamente lo stato della batteria del Mac.

## Impostazioni

Dalle impostazioni è possibile configurare il comportamento di Dynamic Notch, compreso il display su cui visualizzarla in presenza di più monitor.

L’applicazione viene eseguita principalmente come utility nella menu bar.

## Requisiti

- macOS
- Mac compatibile con le funzionalità utilizzate
- consigliato un MacBook con notch

Dynamic Notch è stato sviluppato e testato principalmente su MacBook Pro 14" con Apple Silicon.

## Permessi

Alcune funzionalità richiedono permessi di sistema.

### Calendario

L’accesso al Calendario viene utilizzato esclusivamente per mostrare gli eventi all’interno della sezione Agenda.

### Accessibilità

Alcuni controlli multimediali possono richiedere il permesso Accessibilità di macOS.

Il permesso deve essere concesso manualmente dall’utente dalle Impostazioni di Sistema.

## Installazione

Scarica l’ultima versione dalla sezione **Releases** del repository.

Dopo aver scaricato l’app:

1. sposta `Dynamic Notch.app` nella cartella `Applicazioni`;
2. avvia Dynamic Notch;
3. concedi gli eventuali permessi richiesti dalle funzionalità che vuoi utilizzare.

Poiché le prime versioni possono non essere distribuite tramite Mac App Store, macOS potrebbe mostrare un avviso di sicurezza al primo avvio.

## Sviluppo

Dynamic Notch è sviluppato principalmente con:

- Swift
- SwiftUI
- AppKit
- Combine

Il progetto utilizza inoltre API di sistema per l’integrazione con media, display, calendario e hardware macOS.

## Note tecniche

Dynamic Notch utilizza alcune integrazioni macOS non disponibili tramite le sole API pubbliche standard.

In particolare alcune funzionalità multimediali e di controllo del display possono dipendere da API private o non documentate.

Per questo motivo il progetto è pensato principalmente come progetto open-source e sperimentale e alcune funzionalità potrebbero cambiare con gli aggiornamenti di macOS.

## Privacy

Dynamic Notch funziona localmente sul Mac.

I dati utilizzati da funzionalità come clipboard, agenda, timer e file shelf vengono elaborati localmente e non vengono inviati a server esterni.

## Stato del progetto

Versione corrente:

**v1.0.0**

La prima versione include le funzionalità principali previste per il progetto.

## Licenza

La licenza del progetto verrà indicata nel file `LICENSE`.

## Autore

Progetto sviluppato da **Francesco Aloisio**.

---

Se trovi un bug o hai un suggerimento, puoi aprire una Issue nel repository.
