export default async function handler(req, res) {
  // Setup Headers agar tidak kena blokir browser (CORS)
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: "Gunakan POST" });

  try {
    const body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
    const { projName, code } = body;
    
    const TOKEN = process.env.GITHUB_TOKEN;
    const REPO = process.env.GITHUB_REPO;

    if (!TOKEN || !REPO) throw new Error("Environment Variables (TOKEN/REPO) Kosong di Vercel!");

    const url = `https://api.github.com/repos/${REPO}/contents/scripts/${projName}`;

    // 1. Ambil SHA (untuk update file lama)
    let sha = "";
    const check = await fetch(url, { headers: { Authorization: `token ${TOKEN}` } });
    if (check.ok) {
      const data = await check.json();
      sha = data.sha;
    }

    // 2. Kirim ke GitHub
    const response = await fetch(url, {
      method: 'PUT',
      headers: { 
        Authorization: `token ${TOKEN}`, 
        'Content-Type': 'application/json',
        'User-Agent': 'Bintz-Uploader'
      },
      body: JSON.stringify({
        message: `Bintz System: Update ${projName}`,
        content: Buffer.from(code).toString('base64'),
        sha: sha || undefined
      })
    });

    const result = await response.json();

    if (response.ok) {
      res.status(200).json({ success: true, path: projName });
    } else {
      res.status(response.status).json({ error: result.message || "GitHub API Error" });
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
}      method: 'PUT',
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
