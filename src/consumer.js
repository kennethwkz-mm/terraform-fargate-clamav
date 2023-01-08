import {
  DeleteObjectCommand,
  GetObjectCommand,
  PutObjectCommand,
  PutObjectTaggingCommand,
  S3Client,
} from "@aws-sdk/client-s3";
import { exec } from "node:child_process";
import * as fs from "node:fs";
import consumers from "node:stream/consumers";
import { promisify } from "node:util";
import { Consumer } from "sqs-consumer";
import * as tmp from "tmp";

const execPromise = promisify(exec);

const s3 = new S3Client();

const app = Consumer.create({
  queueUrl: process.env.VIRUS_SCAN_QUEUE_URL,
  handleMessage: async (message) => {
    console.log("message", JSON.stringify(message));
    const parsedBody = JSON.parse(message.Body);

    if (parsedBody.Event === "s3:TestEvent") {
      return;
    }

    const documentKey = parsedBody.Records[0].s3.object.key;

    try {
      const getObjCommand = new GetObjectCommand({
        Bucket: process.env.QUARANTINE_BUCKET,
        Key: documentKey,
      });
      const { Body: fileData } = await s3.send(getObjCommand);
      const data = await consumers.buffer(fileData);

      const inputFile = tmp.fileSync({
        mode: 0o644,
      });
      fs.writeSync(inputFile.fd, data);
      fs.closeSync(inputFile.fd);

      await execPromise(`clamdscan ${inputFile.name}`);

      const putObjCommand = new PutObjectCommand({
        Body: data,
        Bucket: process.env.CLEAN_BUCKET,
        Key: documentKey,
        Tagging: "virus-scan-status=clean",
      });
      await s3.send(putObjCommand);

      const deleteObjCommand = new DeleteObjectCommand({
        Bucket: process.env.QUARANTINE_BUCKET,
        Key: documentKey,
      });
      await s3.send(deleteObjCommand);
    } catch (e) {
      if (e.code === 1) {
        const putObjTagCommand = new PutObjectTaggingCommand({
          Bucket: process.env.QUARANTINE_BUCKET,
          Key: documentKey,
          Tagging: {
            TagSet: [
              {
                Key: "virus-scan-status",
                Value: "infected",
              },
            ],
          },
        });
        await s3.send(putObjTagCommand);
      } else {
        console.log("Errors: ", JSON.stringify(e));
      }
    }
  },
});

app.on("error", (err) => {
  console.error("err", JSON.stringify(err));
});

app.on("processing_error", (err) => {
  console.error("processing error", JSON.stringify(err));
});

app.on("timeout_error", (err) => {
  console.error("timeout error", JSON.stringify(err));
});

app.start();
