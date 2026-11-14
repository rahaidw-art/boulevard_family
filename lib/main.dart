import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/* ================= CONFIGURATION ================= */
// 👉 COLLEZ ICI L'URL /exec DE VOTRE GOOGLE APPS SCRIPT
const String APPS_SCRIPT_URL = "https://script.google.com/macros/s/VOTRE_ID/exec";

const int MONTANT_REFERENCE = 3000; // FCFA / semaine
const List<String> MEMBRES = [
  "S1thox", "Affis", "Ichac", "Rahaid", "Mr Alex",
  "Cheick", "Moutsatou", "Nzeyi", "Davel"
];
const String PREMIER_LUNDI = "2026-06-08"; // lundi de la semaine du 09/06/2026
int nbSemaines = 26;

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boulevard Family',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1E7D4F)),
      home: const PageCotisations(),
    );
  }
}

class PageCotisations extends StatefulWidget {
  const PageCotisations({super.key});
  @override
  State<PageCotisations> createState() => _PageCotisationsState();
}

class _PageCotisationsState extends State<PageCotisations> {
  // data = { "2026-06-08": { "S1thox": 3000, ... }, ... }
  Map<String, Map<String, int>> data = {};
  final Map<String, TextEditingController> _ctrl = {};
  bool chargement = true;
  bool enLigne = false;
  String statut = "⏳ Chargement…";

  /* ================= DATES ================= */
  List<String> genererSemaines(int n) {
    final List<String> semaines = [];
    DateTime d = DateTime.parse(PREMIER_LUNDI);
    for (int i = 0; i < n; i++) {
      semaines.add(d.toIso8601String().substring(0, 10));
      d = d.add(const Duration(days: 7));
    }
    return semaines;
  }

  String formatDateFR(String dateStr) {
    final d = DateTime.parse(dateStr);
    return "${d.day.toString().padLeft(2, '0')}/"
           "${d.month.toString().padLeft(2, '0')}/"
           "${d.year.toString().substring(2)}";
  }

  /* ================= GOOGLE SHEETS ================= */
  Future<void> charger() async {
    setState(() { chargement = true; statut = "⏳ Chargement…"; });
    try {
      final r = await http.get(Uri.parse(APPS_SCRIPT_URL));
      final res = jsonDecode(r.body);
      if (res["ok"] != true) throw Exception(res["erreur"] ?? "Erreur");
      final Map<String, Map<String, int>> tmp = {};
      for (final l in res["lignes"]) {
        tmp.putIfAbsent(l["date"] as String, () => {});
        tmp[l["date"]]![l["membre"] as String] = (l["montant"] as num).toInt();
      }
      _ctrl.clear();
      setState(() {
        data = tmp;
        enLigne = true;
        chargement = false;
        statut = "☁️ Synchronisé ✔ (${(res["lignes"] as List).length} cotisation(s))";
      });
    } catch (e) {
      setState(() {
        chargement = false;
        statut = "⚠️ Hors ligne ou URL invalide";
      });
    }
  }

  Future<void> envoyerVersCloud(String date, String membre, int? montant) async {
    if (!enLigne) return;
    try {
      await http.post(
        Uri.parse(APPS_SCRIPT_URL),
        headers: {"Content-Type": "text/plain;charset=utf-8"}, // évite le blocage CORS
        body: jsonEncode({"action": "ecrire", "date": date, "membre": membre, "montant": montant}),
      );
      setState(() => statut = "☁️ Enregistré dans Google Sheets ✔");
    } catch (_) {
      setState(() => statut = "⚠️ Échec d'enregistrement — vérifiez la connexion");
    }
  }

  /* ================= SAISIE ================= */
  void setMontant(String semaine, String membre, String valeur) {
    final v = int.tryParse(valeur);
    setState(() {
      data.putIfAbsent(semaine, () => {});
      if (v == null || v <= 0) {
        data[semaine]!.remove(membre);
        if (data[semaine]!.isEmpty) data.remove(semaine);
        envoyerVersCloud(semaine, membre, null);
      } else {
        data[semaine]![membre] = v;
        envoyerVersCloud(semaine, membre, v);
      }
    });
  }

  /* ================= CALCULS ================= */
  int montant(String semaine, String membre) => data[semaine]?[membre] ?? -1;

  int totalSemaine(String s) =>
      MEMBRES.fold(0, (a, m) => a + (data[s]?[m] ?? 0));

  /* ================= INTERFACE ================= */
  @override
  void initState() { super.initState(); charger(); }

  @override
  void dispose() {
    for (final c in _ctrl.values) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final semaines = genererSemaines(nbSemaines);
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("💰 Boulevard Family", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text("Cotisation hebdomadaire — 3000 FCFA", style: TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: const Color(0xFF1E7D4F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.sync), onPressed: charger, tooltip: "Synchroniser"),
          IconButton(
            icon: const Icon(Icons.add_box),
            tooltip: "Ajouter une semaine",
            onPressed: () => setState(() => nbSemaines++),
          ),
        ],
      ),
      body: chargement
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(statut,
                        style: TextStyle(
                          color: statut.startsWith("⚠") ? Colors.red : const Color(0xFF1E7D4F),
                        )),
                  ),
                  const Text("📅 Grille de suivi hebdomadaire",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(8),
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(const Color(0xFF1E7D4F)),
                      headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      columnSpacing: 12,
                      columns: [
                        const DataColumn(label: Text("Membre")),
                        ...semaines.map((s) => DataColumn(
                              label: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(formatDateFR(s), style: const TextStyle(fontSize: 11)),
                                  Text(s.substring(5), style: const TextStyle(fontSize: 9)),
                                ],
                              ),
                            )),
                      ],
                      rows: [
                        for (final m in MEMBRES)
                          DataRow(cells: [
                            DataCell(Text(m, style: const TextStyle(fontWeight: FontWeight.bold))),
                            ...semaines.map((s) {
                              final v = montant(s, m);
                              final key = "$s|$m";
                              final ctrl = _ctrl.putIfAbsent(
                                key,
                                () => TextEditingController(text: v > 0 ? "$v" : ""),
                              );
                              return DataCell(
                                Container(
                                  width: 70,
                                  color: v > 0 ? const Color(0xFFE6F6EC) : const Color(0xFFFDEBEC),
                                  child: TextField(
                                    controller: ctrl,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: const InputDecoration(
                                        border: InputBorder.none, hintText: "—"),
                                    onSubmitted: (val) => setMontant(s, m, val),
                                  ),
                                ),
                              );
                            }),
                          ]),
                        DataRow(cells: [
                          const DataCell(Text("TOTAL", style: TextStyle(fontWeight: FontWeight.bold))),
                          ...semaines.map((s) => DataCell(Text(
                                "${totalSemaine(s)} F",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ))),
                        ]),
                      ],
                    ),
                  ),
                  const Divider(),
                  const Text("📊 Résumé par membre",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(8),
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text("Membre")),
                        DataColumn(label: Text("Cotisées")),
                        DataColumn(label: Text("Versé (F)")),
                        DataColumn(label: Text("Attendu (F)")),
                        DataColumn(label: Text("Dette")),
                      ],
                      rows: [
                        for (final m in MEMBRES)
                          DataRow(cells: (() {
                            int payees = 0, verse = 0;
                            data.forEach((_, mm) {
                              if (mm[m] != null) { payees++; verse += mm[m]!; }
                            });
                            final attendu = nbSemaines * MONTANT_REFERENCE;
                            final dette = attendu - verse > 0 ? attendu - verse : 0;
                            return [
                              DataCell(Text(m, style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text("$payees / $nbSemaines")),
                              DataCell(Text("$verse")),
                              DataCell(Text("$attendu")),
                              DataCell(dette > 0
                                  ? Chip(
                                      label: Text("$dette F",
                                          style: const TextStyle(color: Colors.white, fontSize: 12)),
                                      backgroundColor: const Color(0xFFC0392B),
                                    )
                                  : const Chip(
                                      label: Text("À jour ✔",
                                          style: TextStyle(color: Colors.white, fontSize: 12)),
                                      backgroundColor: Color(0xFF1E7D4F),
                                    )),
                            ];
                          })()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
