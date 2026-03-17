export default async function handler(req, res) {
  const { name } = req.query;
  const REPO = process.env.GITHUB_REPO;

  try {
    const response = await fetch(`https://raw.githubusercontent.com/${REPO}/main/scripts/${name}`);
    
    if (!response.ok) {
      res.setHeader('Content-Type', 'text/plain');
      return res.status(404).send("Error: Script '" + name + "' tidak ditemukan.");
    }

    const data = await response.text();
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.status(200).send(data);
  } catch (e) {
    res.status(500).send("Server Error: " + e.message);
  }
}
