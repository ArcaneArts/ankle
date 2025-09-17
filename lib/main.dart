import 'dart:math';

import 'package:arcane/arcane.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

void main() => runApp("ankle", AnkleApp());

class AnkleApp extends StatelessWidget {
  const AnkleApp({super.key});

  @override
  Widget build(BuildContext context) => ArcaneApp(home: AnkleScreen());
}

class AnkleScreen extends StatefulWidget {
  const AnkleScreen({super.key});

  @override
  State<AnkleScreen> createState() => _AnkleScreenState();
}

class _AnkleScreenState extends State<AnkleScreen> {
  String charset = "";
  String outputTexture = "INVALID CHARSET";
  String toEncode = "";
  String toDecode = "";
  int threshold = 2;
  String gen = "ERROR";
  Set<String> burned = {};
  List<int> copies = List.generate(256, (i) => 0);
  String decodedTry = "";

  String genTexture(int l) {
    try {
      return charset.genAsCharset(l);
    } catch (e) {
      return "INVALID CHARSET";
    }
  }

  List<String> genShares() {
    try {
      return SSSS
          .encodeShares(
            secretBytes: toEncode.encodedUtf8,
            threshold: threshold,
            seed: "$toEncode$charset$threshold".hashCode,
          )
          .take(min(max(2, 2 * threshold), 255))
          .map((i) => i.encodeBundleCharset(charset))
          .toList();
    } catch (e) {
      return ["ERROR"];
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      decodedTry = SSSS
          .decodeSSS(toDecode.split("\n").map((i) => i.decodedBundle).toList())
          .utf8;
    } catch (e, es) {
      if (kDebugMode) {
        print(e);
        print(es);
      }
      decodedTry = "ERROR: $e";
    }

    return ArcaneScreen(
      child: Collection(
        children: [
          Gap(16),
          ...<Widget>[
            TrustBox(
              AnimatedSize(
                duration: 200.milliseconds,
                curve: Curves.easeOutCirc,
                child: CardSection(
                  title: Text("Charset"),
                  subtitle: OverflowMarquee(child: Text(charset)),
                  leadingIcon: Icons.text_aa,
                  children: [
                    Tabbed(
                      indexedStack: false,
                      tabs: {
                        "Preset": Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Card(
                              padding: EdgeInsetsGeometry.zero,
                              borderColor: Colors.transparent,
                              borderWidth: 0,
                              filled: true,
                              fillColor: Theme.of(
                                context,
                              ).colorScheme.card.withOpacity(0.5),
                              child: Select<String>(
                                itemBuilder: (context, item) {
                                  return Basic(
                                    title: Text(
                                      item.lowerCamelCaseToUpperSpacedCase,
                                    ),
                                    subtitle: OverflowMarquee(
                                      child: Text(
                                        (charsetPalettes[item] ?? "bad"),
                                      ),
                                    ),
                                  );
                                },
                                placeholder: Text("Select a preset").muted,
                                popupWidthConstraint:
                                    PopoverConstraint.anchorMaxSize,
                                onChanged: (value) => setState(() {
                                  charset =
                                      charsetPalettes[value ?? "error"] ??
                                      "fail";
                                }),
                                constraints: BoxConstraints(
                                  minWidth: double.maxFinite,
                                ),
                                value: charset.isEmpty
                                    ? null
                                    : charsetPalettes
                                          .where((k, v) => v == charset)
                                          .keys
                                          .firstOrNull,
                                popup: SelectPopup(
                                  items: SelectItemList(
                                    children: [
                                      ...charsetPalettes.keys.map(
                                        (i) => SelectItemButton(
                                          value: i,
                                          child: Basic(
                                            title: Text(
                                              i.lowerCamelCaseToUpperSpacedCase,
                                            ),
                                            subtitle: OverflowMarquee(
                                              child: Text(
                                                (charsetPalettes[i] ?? "bad"),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ).call,
                              ),
                            ),
                          ],
                        ),
                        "Custom": TextField(
                          initialValue: charset,
                          placeholder: Text(
                            "Enter anything here to make a charset out of it",
                          ),
                          onChanged: (value) => setState(() {
                            charset = String.fromCharCodes(
                              value.codeUnits.unique,
                            );
                          }),
                        ),
                      },
                    ),
                    Gap(8),
                    Text(
                      "You can choose a preset charset or enter one manually under custom. You will see your charset at the top of this card.",
                    ).muted.xSmall,
                    Gap(8),
                    Divider(child: Text("Result")),
                    Gap(8),
                    OverflowMarquee(
                      child: Text(
                        "${genTexture(1024)}\n${genTexture(1024)}\n${genTexture(1024)}\n${genTexture(1024)}\n${genTexture(1024)}\n${genTexture(1024)}\n${genTexture(1024)}\n${genTexture(1024)}",
                      ).muted.large,
                    ),
                  ],
                ),
              ),
            ),
            TrustBox(
              AnimatedSize(
                duration: 200.milliseconds,
                curve: Curves.easeOutCirc,
                child: CardSection(
                  title: Text("Codec"),
                  leadingIcon: Icons.code,
                  children: [
                    Tabbed(
                      indexedStack: false,
                      tabs: {
                        "Encode": Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    initialValue: toEncode,
                                    placeholder: Text("Enter text to encode"),
                                    onChanged: (s) => setState(() {
                                      toEncode = s;
                                    }),
                                  ),
                                ),

                                Gap(8),
                                SizedBox(
                                  child: TextField(
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    initialValue: threshold.toString(),
                                    onChanged: (v) {
                                      int? g = int.tryParse(v.trim());
                                      g ??= 2;
                                      if (g < 2) {
                                        g = 2;
                                      }

                                      if (g > 255) {
                                        g = 255;
                                      }

                                      setState(() {
                                        threshold = g!;
                                      });
                                    },
                                    features: [
                                      InputFeature.spinner(step: 1),
                                      InputFeature.leading(
                                        Icon(Icons.tree_structure_fill),
                                      ),
                                    ],
                                  ).iw,
                                ),
                              ],
                            ),
                            Gap(8),
                            KeyedSubtree(
                              child: Column(
                                children: [
                                  ...genShares().mapIndexed(
                                    (i, ind) =>
                                        ListTile(
                                              leadingIcon: Icons.check_circle,
                                              trailing: Icon(Icons.copy),
                                              titleText: i,
                                              onPressed: () {
                                                Clipboard.setData(
                                                  ClipboardData(text: i),
                                                );
                                                setState(() {
                                                  copies[ind]++;
                                                });
                                              },
                                            )
                                            .animate(
                                              key: ValueKey(
                                                "Copy.$ind.${copies[ind]}",
                                              ),
                                            )
                                            .fadeIn(
                                              duration: const Duration(
                                                milliseconds: 700,
                                              ),
                                              curve: Curves.easeOutExpo,
                                            )
                                            .color(
                                              duration: 700.ms,
                                              curve: Curves.easeOutExpo,
                                              begin: Colors.blue.lerp(
                                                Colors.white,
                                                0.5,
                                              ),
                                              end: Colors.transparent,
                                            )
                                            .blurXY(
                                              begin: 96,
                                              end: 0,
                                              duration: const Duration(
                                                milliseconds: 750,
                                              ),
                                              curve: Curves.easeOutCirc,
                                            ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        "Decode": Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              placeholder: Text(
                                "Enter shares, one per line.\nCodec above is not used for decoding.",
                              ),
                              initialValue: toDecode,
                              maxLines: 12,
                              minLines: 2,
                              onChanged: (s) => setState(() {
                                toDecode = s;
                              }),
                            ),
                            Gap(8),
                            Divider(child: Text("Result")),
                            Gap(8),
                            Text(decodedTry).muted,
                          ],
                        ),
                      },
                    ),
                  ],
                ),
              ),
            ),
          ].joinSeparator(Gap(16)),
          Gap(16),
        ],
      ).padSliverHorizontal(16),
    );
  }
}
