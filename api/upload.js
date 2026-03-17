export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).send();
  
  const { projName, fileName, code } = JSON.parse(req.body);
  const TOKEN = "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"; 
  const REPO = "bintzstore/raw-script";

  // Kita simpan file dengan namaProyek sebagai folder agar mudah diakses api/v1
  const url = `https://api.github.com/repos/${REPO}/contents/scripts/${projName}`;

  let sha = "";
  const check = await fetch(url, { headers: { Authorization: `token ${TOKEN}` } });
  if (check.ok) {
    const data = await check.json();
    sha = data.sha;
  }

  const response = await fetch(url, {
    method: 'PUT',
    headers: { Authorization: `token ${TOKEN}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      message: `Bintz System: Upload ${projName} (${fileName})`,
      content: Buffer.from(code).toString('base64'),
      sha: sha || undefined
    })
  });

  if (response.ok) res.status(200).json({ success: true });
  else res.status(500).json({ error: "Gagal GitHub API" });
}
