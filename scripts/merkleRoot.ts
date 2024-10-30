import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";
import csv from "csv-parser";

export interface IRow {
  address: string;
  amount: string;
}

export interface IProofs {
  [key: string]: string[];
}

const values: string[][] = [];
fs.createReadStream("../lib/eligibleAccounts.csv")
  .pipe(csv())
  .on("data", (row: IRow) => {
    values.push([row.address, row.amount]);
  })
  .on("end", () => {
    const tree = StandardMerkleTree.of(values, ["address", "uint256"]);
    console.log("Merkle Root:", tree.root);

    fs.writeFileSync("tree.json", JSON.stringify(tree.dump()));

    const proofs: IProofs = {};

    try {
      const loadedTree = StandardMerkleTree.load(
        JSON.parse(fs.readFileSync("tree.json", "utf8"))
      );
      for (const [i, v] of loadedTree.entries()) {
        const proof: string[] = loadedTree.getProof(i);
        proofs[v[0]] = proof;
      }

      fs.writeFileSync("proofs.json", JSON.stringify(proofs, null, 2));
      console.log("All proofs have been saved to 'proofs.json'.");
    } catch (err) {
      console.error("Error reading or processing 'tree.json':", err);
    }
  })
  .on("error", (err) => {
    console.error("Error reading 'airdrop.csv':", err);
  });

//merkle root: 0xce3dd3f5d99df66074b463d2fca6ca74556d2fe05551f1391319778c6556dae2
