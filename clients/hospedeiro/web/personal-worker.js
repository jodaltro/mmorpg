/* Go world simulation stays off the rendering thread. No network here. */
importScripts('wasm_exec.js');
const started = (async () => {
  const go = new Go();
  const bytes = await (await fetch('worldsim-local.wasm')).arrayBuffer();
  const {instance} = await WebAssembly.instantiate(bytes, go.importObject);
  go.run(instance); // runtime lives until worker termination
})();
let chain = started;
self.onmessage = ({data}) => {
  chain = chain.then(() => {
    try { self.postMessage({id:data.id, ...JSON.parse(self.worldsimLocal(JSON.stringify(data)))}); }
    catch (err) { self.postMessage({id:data.id,error:String(err)}); }
  });
};
