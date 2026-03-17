export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: "Method Not Allowed" });

  try {
    const { projName, code } = req.body;
    const TOKEN = process.env.GITHUB_TOKEN;
    const REPO = process.env.GITHUB_REPO;

    if (!TOKEN || !REPO) throw new Error("Config Vercel (Token/Repo) belum di-set!");

    const url = `https://api.github.com/repos/${REPO}/contents/scripts/${projName}`;

    // Cek file lama untuk ambil SHA
    let sha = "";
    const checkFile = await fetch(url, { headers: { Authorization: `token ${TOKEN}` } });
    if (checkFile.ok) {
      const data = await checkFile.json();
      sha = data.sha;
    }

    // Upload ke GitHub
    const upload = await fetch(url, {
      method: 'PUT',
      headers: { 
        Authorization: `token ${TOKEN}`, 
        'Content-Type': 'application/json',
        'User-Agent': 'Bintz-App'
      },
      body: JSON.stringify({
        message: `Bintz System: Update ${projName}`,
        content: Buffer.from(code).toString('base64'),
        sha: sha || undefined
      })
    });

    const result = await upload.json();

    if (upload.ok) {
      return res.status(200).json({ success: true, path: projName });
    } else {
      return res.status(500).json({ error: result.message || "Gagal ke GitHub API" });
    }

  } catch (err) {
    return res.status(500).json({ error: "Server Error: " + err.message });
  }
}
