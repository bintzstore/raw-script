export default async function handler(req, res) {
  // Biar bisa diakses dari mana saja
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).send("Method Not Allowed");

  try {
    const { projName, fileName, code } = JSON.parse(req.body);
    
    // Ambil dari Environment Variables Vercel
    const TOKEN = process.env.GITHUB_TOKEN; 
    const REPO = process.env.GITHUB_REPO; 

    if (!TOKEN || !REPO) {
      return res.status(500).json({ error: "Token atau Repo belum di-set di Environment Variables Vercel!" });
    }

    // Path folder scripts di GitHub
    const url = `https://api.github.com/repos/${REPO}/contents/scripts/${projName}`;

    // 1. Cek apakah file sudah ada (untuk dapet SHA)
    let sha = "";
    const checkFile = await fetch(url, {
      headers: { Authorization: `token ${TOKEN}` }
    });
    
    if (checkFile.ok) {
      const existingData = await checkFile.json();
      sha = existingData.sha;
    }

    // 2. Proses Upload/Update
    const uploadRes = await fetch(url, {
      method: 'PUT',
      headers: {
        Authorization: `token ${TOKEN}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        message: `Bintz System: Update ${projName}`,
        content: Buffer.from(code).toString('base64'),
        sha: sha || undefined
      })
    });

    const result = await uploadRes.json();

    if (uploadRes.ok) {
      res.status(200).json({ success: true, url: `/api/v1/${projName}` });
    } else {
      res.status(500).json({ error: result.message || "Gagal upload ke GitHub" });
    }

  } catch (err) {
    res.status(500).json({ error: "Internal Server Error: " + err.message });
  }
}
