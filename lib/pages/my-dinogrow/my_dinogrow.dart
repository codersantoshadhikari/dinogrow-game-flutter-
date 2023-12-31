// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:solana/solana.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ui/widgets/widgets.dart';

import 'dart:math';
import 'package:solana/solana.dart' as solana;
import 'package:solana/anchor.dart' as solana_anchor;
import 'package:solana/encoder.dart' as solana_encoder;
import 'package:solana_common/utils/buffer.dart' as solana_buffer;
import '../../anchor_types/nft_parameters.dart' as anchor_types;

class MydinogrowScreen extends StatefulWidget {
  final String address;
  final Function getBalance;

  const MydinogrowScreen(
      {super.key, required this.address, required this.getBalance});

  @override
  State<MydinogrowScreen> createState() => _MydinogrowScreenState();
}

class _MydinogrowScreenState extends State<MydinogrowScreen> {
  final storage = const FlutterSecureStorage();
  bool _loading = true;
  var userNfts = [];
  int nftSelected = 0;

  final filters = [
    Colors.white,
    ...List.generate(
      Colors.primaries.length,
      (index) => Colors.primaries[(index * 4) % Colors.primaries.length],
    )
  ];

  List<Widget> mintContent() => [
        const IntroLogoWidget(),
        const SizedBox(height: 30),
        IntroButtonWidget(
          text: 'Claim your Dino',
          onPressed: createNft,
        ),
        const SizedBox(height: 30),
        Container(
          color: Colors.orange[700],
          padding: const EdgeInsets.all(8),
          child: const Text(
            'Wait ... you must to have a Dino to start play our games, so "Claim your Dino" is our last step to auto-generate your first NFT! Remember you must have at least 0.5 SOL in you wallet balance',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        )
      ];

  List<Widget> myDinosContent(returnImageColorFc) => [
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            itemCount: userNfts.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => selectNewDino(index),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: nftSelected == index
                          ? Colors.white
                          : Colors.transparent,
                      width: 6,
                    ),
                    borderRadius: BorderRadius.circular(45),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(45),
                    child: Image.network(
                      userNfts[index]['imageUrl'],
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      colorBlendMode: BlendMode.color,
                      loadingBuilder: (BuildContext context, Widget child,
                          ImageChunkEvent? loadingProgress) {
                        if (loadingProgress == null) {
                          return child;
                        }
                        return Container(
                          color: Colors.black,
                          width: 120,
                          height: 120,
                        );
                      },
                    ),
                    // child: returnImageColorFc(index),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 30),
        GameCardWidget(
          text: userNfts.isNotEmpty ? userNfts[nftSelected]['name'] : '',
          urlImage:
              userNfts.isNotEmpty ? userNfts[nftSelected]['imageUrl'] : '',
        ),
        const SizedBox(height: 12),
        Container(
          color: Colors.black,
          child: const Padding(
            padding: EdgeInsets.all(3),
            child: Text(
              "Hi ^.^ Please choose one Dino to use it as your avatar",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
        IntroButtonWidget(
          text: 'Claim other Dino',
          onPressed: beforeOtherNft,
        ),
      ];

  bool showDinos = false;

  @override
  void initState() {
    super.initState();
    fetchNfts();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ...(showDinos && userNfts.isNotEmpty
                      ? myDinosContent(returnImageColor)
                      : mintContent()),
                  const SizedBox(height: 30),
                  IntroButtonWidget(
                    text: 'Log out',
                    onPressed: () => logout(context),
                    size: 'fit',
                    variant: 'disabled',
                  )
                ]),
          ),
        ),
      ),
    );
  }

  void logout(BuildContext context) async {
    while (GoRouter.of(context).canPop() == true) {
      GoRouter.of(context).pop();
    }
    GoRouter.of(context).pushReplacement("/");
    // await storage.delete(key: 'mnemonic');
  }

  Image returnImageColor(int index) {
    if (index == 0) {
      return Image.asset(
        'assets/images/logo.jpeg',
        width: 90,
        height: 90,
        fit: BoxFit.cover,
        colorBlendMode: BlendMode.color,
      );
    }

    return Image.asset(
      'assets/images/logo.jpeg',
      width: 90,
      height: 90,
      fit: BoxFit.cover,
      colorBlendMode: BlendMode.color,
      color: filters[index],
    );
  }

  selectNewDino(int index) async {
    setState(() {
      nftSelected = index;
    });

    await storage.write(
        key: 'dinoSelected', value: userNfts[index]['tokenAddress']);
  }

  Future<void> fetchNfts() async {
    try {
      ('widget.address: ${widget.address}');
      setState(() {
        _loading = true;
        userNfts = [];
        showDinos = false;
      });

      String? dinoSelected = await storage.read(key: 'dinoSelected');

      await dotenv.load(fileName: ".env");

      final response = await http.post(
          Uri.parse(dotenv.env['QUICKNODE_RPC_URL'].toString()),
          headers: <String, String>{
            'Content-Type': 'application/json',
            "x-qn-api-version": '1'
          },
          body: jsonEncode({
            "method": "qn_fetchNFTs",
            "params": {"wallet": widget.address, "page": 1, "perPage": 10}
          }));

      final dataResponse = jsonDecode(response.body);
      final arrayAssets = dataResponse['result']['assets'];
      final filteredData = arrayAssets
          .where((nft) =>
              nft['imageUrl'] != '' && nft['collectionName'] == 'DINOGROW')
          .toList();

      if (filteredData.length == 1 ||
          (filteredData.length > 0 &&
              (dinoSelected == null || dinoSelected.isEmpty))) {
        await storage.write(
            key: 'dinoSelected', value: filteredData[0]['tokenAddress']);
        setState(() {
          nftSelected = 0;
        });
      } else if (dinoSelected != null && dinoSelected.isNotEmpty) {
        int index = filteredData
            .indexWhere((item) => item["tokenAddress"] == dinoSelected);
        setState(() {
          nftSelected = index;
        });
      }

      if (mounted) {
        setState(() {
          userNfts = filteredData;
          showDinos = true;
        });
      }
    } finally {
      if (mounted) {
        Future.delayed(const Duration(seconds: 1), () async {
          setState(() {
            _loading = false;
          });
          Future.delayed(const Duration(seconds: 2), () async {
            widget.getBalance();
          });
        });
      }
    }
  }

  beforeOtherNft() {
    showDialog<String>(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Claim other Dino'),
        content: const Text(
            'Before to continue, are you sure to claim other Dino? Remember the transaction has a variable cost so please confirm if you have at least 0.05 SOL in your wallet balance.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, 'Cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              createNft();
              Navigator.pop(context, 'OK');
            },
            child: const Text('Confimr'),
          ),
        ],
      ),
    );
  }

  showrResultMessage(String transaction) {
    showDialog<String>(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('New Dino claimed'),
        content: Text(
            "Congrats, you already have new Dino NFT! \n\nIf you want, you can review information on blockchain with this transaction reference: \n\n$transaction"),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Back"),
          ),
          TextButton(
            onPressed: () {
              _launchUrl(transaction);
            },
            child: const Text('View transaction'),
          ),
        ],
      ),
    );
  }

  createNft() async {
    try {
      if (_loading) {
        // avoid double call
        return null;
      }

      if (mounted) {
        setState(() {
          _loading = true;
        });
      }

      await dotenv.load(fileName: ".env");

      SolanaClient? client;
      client = SolanaClient(
        rpcUrl: Uri.parse(dotenv.env['QUICKNODE_RPC_URL'].toString()),
        websocketUrl: Uri.parse(dotenv.env['QUICKNODE_RPC_WSS'].toString()),
      );
      const storage = FlutterSecureStorage();

      final mainWalletKey = await storage.read(key: 'mnemonic');

      final mainWalletSolana = await solana.Ed25519HDKeyPair.fromMnemonic(
        mainWalletKey!,
      );

      final programId = dotenv.env['PROGRAM_ID'].toString();

      final programIdPublicKey =
          solana.Ed25519HDPublicKey.fromBase58(programId);

      int idrnd = Random().nextInt(999);
      String id = "Dino$idrnd";
      // print(id);

      final nftMintPda = await solana.Ed25519HDPublicKey.findProgramAddress(
          programId: programIdPublicKey,
          seeds: [
            solana_buffer.Buffer.fromString("mint"),
            solana_buffer.Buffer.fromString(id),
          ]);
      // print(nftMintPda.toBase58());

      final ataProgramId = solana.Ed25519HDPublicKey.fromBase58(
          solana.AssociatedTokenAccountProgram.programId);

      final systemProgramId =
          solana.Ed25519HDPublicKey.fromBase58(solana.SystemProgram.programId);
      final tokenProgramId =
          solana.Ed25519HDPublicKey.fromBase58(solana.TokenProgram.programId);

      final rentProgramId = solana.Ed25519HDPublicKey.fromBase58(
          "SysvarRent111111111111111111111111111111111");

      const metaplexProgramId = 'metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s';
      final metaplexProgramIdPublicKey =
          solana.Ed25519HDPublicKey.fromBase58(metaplexProgramId);

      final aTokenAccount = await solana.Ed25519HDPublicKey.findProgramAddress(
        seeds: [
          mainWalletSolana.publicKey.bytes,
          tokenProgramId.bytes,
          nftMintPda.bytes,
        ],
        programId: ataProgramId,
      );
      // print(aTokenAccount.toBase58());

      final masterEditionAccountPda =
          await solana.Ed25519HDPublicKey.findProgramAddress(
        seeds: [
          solana_buffer.Buffer.fromString("metadata"),
          metaplexProgramIdPublicKey.bytes,
          nftMintPda.bytes,
          solana_buffer.Buffer.fromString("edition"),
        ],
        programId: metaplexProgramIdPublicKey,
      );
      final nftMetadataPda = await solana.Ed25519HDPublicKey.findProgramAddress(
        seeds: [
          solana_buffer.Buffer.fromString("metadata"),
          metaplexProgramIdPublicKey.bytes,
          nftMintPda.bytes,
        ],
        programId: metaplexProgramIdPublicKey,
      );

      int indexImage = Random().nextInt(5);

      final imagesNfts = [
        'QmPeUExCwWmpqB47EKErgf3E5JWrQPv3kCpfqpzWVHHux8',
        'QmdHkmcWiMmwnwmz6SJDR1J5LLsPH5uSy1BgFAQzkHJWxJ',
        'QmUueQKAY5SFRZBYzKowms3YyJkK7VfJHSBhBYT1GAcs2H',
        'QmQgk3vJFjhphhV1riLEjnLa6cUgKzGwE75egfT3jhuTfM',
        'QmeaphAPRmf1rueJ6QBMyRPYBLKWZ9YMZhHQmcR8csxPxr',
      ];

      final instructions = [
        await solana_anchor.AnchorInstruction.forMethod(
          programId: programIdPublicKey,
          method: 'create_dino_nft',
          arguments: solana_encoder.ByteArray(anchor_types.NftArguments(
            id: id,
            name: "DINOGROW #${userNfts.length + 1}",
            symbol: "DNG",
            uri:
                "https://quicknode.myfilebase.com/ipfs/${imagesNfts[indexImage]}/",
          ).toBorsh().toList()),
          accounts: <solana_encoder.AccountMeta>[
            solana_encoder.AccountMeta.writeable(
                pubKey: nftMintPda, isSigner: false),
            solana_encoder.AccountMeta.writeable(
                pubKey: aTokenAccount, isSigner: false),
            solana_encoder.AccountMeta.readonly(
                pubKey: ataProgramId, isSigner: false),
            solana_encoder.AccountMeta.writeable(
                pubKey: mainWalletSolana.publicKey, isSigner: true),
            solana_encoder.AccountMeta.writeable(
                pubKey: mainWalletSolana.publicKey, isSigner: true),
            solana_encoder.AccountMeta.readonly(
                pubKey: rentProgramId, isSigner: false),
            solana_encoder.AccountMeta.readonly(
                pubKey: systemProgramId, isSigner: false),
            solana_encoder.AccountMeta.readonly(
                pubKey: tokenProgramId, isSigner: false),
            solana_encoder.AccountMeta.readonly(
                pubKey: metaplexProgramIdPublicKey, isSigner: false),
            solana_encoder.AccountMeta.writeable(
                pubKey: masterEditionAccountPda, isSigner: false),
            solana_encoder.AccountMeta.writeable(
                pubKey: nftMetadataPda, isSigner: false),
          ],
          namespace: 'global',
        ),
      ];
      final message = solana.Message(instructions: instructions);
      final signature = await client.sendAndConfirmTransaction(
        message: message,
        signers: [mainWalletSolana],
        commitment: solana.Commitment.confirmed,
      );
      ('Tx successful with hash: $signature');
      showrResultMessage(signature);
      fetchNfts();
    } catch (e) {
      final snackBar = SnackBar(
        content: Text('Error: $e', style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
      );

      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }
}

Future<void> _launchUrl(String transaction) async {
  Uri url = Uri(
      scheme: 'https',
      host: 'explorer.solana.com',
      path: '/tx/$transaction',
      queryParameters: {'cluster': 'devnet'});
  if (!await launchUrl(url)) {
    throw Exception('Could not launch $url');
  }
}
