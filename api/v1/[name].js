export default async function handler(req, res) {
  const { name } = req.query; // Ini adalah namaProyek
  const GITHUB_RAW = `https://raw.githubusercontent.com/USERNAME/REPO/main/scripts/${name}`;

  try {
    const response = await fetch(GITHUB_RAW);
    if (!response.ok) throw new Error();
    
    const data = await response.text();
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.status(200).send(data);
  } catch (e) {
    res.status(404).send("URL Proyek tidak ditemukan.");
  }
}
