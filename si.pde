import controlP5.*;
import ddf.minim.*;
import javax.swing.*;

import ddf.minim.analysis.*;
import ddf.minim.effects.*;
import ddf.minim.ugens.*;

import java.util.*;
import java.net.InetAddress;
import javax.swing.filechooser.FileFilter;
import javax.swing.filechooser.FileNameExtensionFilter;

import org.elasticsearch.action.admin.indices.exists.indices.IndicesExistsResponse;
import org.elasticsearch.action.admin.cluster.health.ClusterHealthResponse;
import org.elasticsearch.action.index.IndexRequest;
import org.elasticsearch.action.index.IndexResponse;
import org.elasticsearch.action.search.SearchResponse;
import org.elasticsearch.action.search.SearchType;
import org.elasticsearch.client.Client;
import org.elasticsearch.common.settings.Settings;
import org.elasticsearch.node.Node;
import org.elasticsearch.node.NodeBuilder;

ControlP5 ui, slide;
ScrollableList list;

Minim minim;
AudioPlayer song;
AudioMetaData meta;

HighPassSP hP;
LowPassFS lPF;
BandPass bP;
int ihP, ilPF, ibP;
float vol=100;

boolean m=false, press= false, car;
Textlabel texto;
FFT          fft;

JFileChooser jFC;

static String INDEX_NAME= "canciones";
static String DOC_TYPE= "cancion";

Client client;
Node node;


void setup() {
  size(360, 430);
  ui= new ControlP5(this);
  ui.addButton("play").setPosition(50, 50).setSize(50, 50).setValue(0);
  ui.addButton("pausa").setPosition(110, 50).setSize(50, 50).setValue(0);
  ui.addButton("parar").setPosition(170, 50).setSize(50, 50).setValue(0);
  ui.addButton("mute").setPosition(230, 50).setSize(50, 50);
  //ui.addButton("volU").setPosition(290, 50).setSize(50, 50);
  //ui.addButton("volD").setPosition(230, 50).setSize(50, 50);
  ui.addButton("seleccionar").setPosition(290, 50).setSize(50, 50).setValue(0);

  slide= new ControlP5(this);
  slide.setColorForeground(155);
  slide.setColorBackground(0);
  slide.setColorActive(0xffff0000);

  ui.addSlider("volumen").setPosition(20, 270).setSize(300, 50).setRange(-40, 0).setNumberOfTickMarks(10).setValue(0);

  ui.addSlider("ibP").setPosition(260, 120).setSize(10, 100).setRange(100, 1000).setNumberOfTickMarks(10).setValue(100);

  ui.addSlider("ilPF").setPosition(290, 120).setSize(10, 100).setRange(60, 2000).setNumberOfTickMarks(10).setValue(3000);

  ui.addSlider("ihP").setPosition(320, 120).setSize(10, 100).setRange(0, 3000).setNumberOfTickMarks(10).setValue(0);

  ui.getController("ihP").getValueLabel().align(ControlP5.RIGHT, ControlP5.BOTTOM_OUTSIDE).setPaddingY(-100);
  ui.getController("ilPF").getValueLabel().align(ControlP5.RIGHT, ControlP5.BOTTOM_OUTSIDE).setPaddingY(-100);
  ui.getController("ibP").getValueLabel().align(ControlP5.RIGHT, ControlP5.BOTTOM_OUTSIDE).setPaddingY(-100);

  list = ui.addScrollableList("playlist").setPosition(30, 110).setSize(200, 400).setBarHeight(20).setItemHeight(20).setType(ScrollableList.LIST);

  minim = new Minim(this);

  jFC= new JFileChooser();

  Settings.Builder settings= Settings.settingsBuilder();
  settings.put("path.data", "esdata");
  settings.put("path.home", "/");
  settings.put("http.enabled", false);
  settings.put("index.number_of_replicas", 0);
  settings.put("index.number_of_shards", 1);

  node= NodeBuilder.nodeBuilder().settings(settings).clusterName("mycluster").data(true).local(true).node();

  client= node.client();

  ClusterHealthResponse r = client.admin().cluster().prepareHealth().setWaitForGreenStatus().get();
  println(r);

  IndicesExistsResponse ier = client.admin().indices().prepareExists(INDEX_NAME).get();
  if (!ier.isExists()) {
    client.admin().indices().prepareCreate(INDEX_NAME).get();
  }

  loadFiles();

  rectMode(CORNERS);
}      


void draw() {
  //if (press) {
  background(150);
  //text(song.length()-song.position(), 200, 245);
  //text("Titulo: "+meta.title(), 200, 260);
  //text("Autor: "+meta.author(), 200, 275);
  if (song!=null) {
    hP.setFreq(ihP);
    lPF.setFreq(ilPF);
    bP.setFreq(ibP);
    fill(random(255), random(0), random(0));
    fft.forward(song.mix);
    int w= int((width-200)/fft.avgSize());
    for (int i = 0; i < fft.avgSize(); i++) {
      rect(i*w, height-30, i*w + w, height-30 - fft.getAvg(i)*3);
    }
    //}
  }
}


public void play() {
  song.play();
  println("play");
}


public void pausa() {
  song.pause();
  println("pausa");
}


public void parar() {
  song.pause();
  song.rewind();
  println("Parar");
}


public void mute() {
  if (m==false) {
    song.mute();
    m=true;
  } else {
    song.unmute();
    m=false;
  }
}


/*public void volU(){
 float v;
 float getVolume(v){
 return v;
 }
 //void setVolume();
 }*/


void seleccionar() {
  jFC.setFileFilter(new FileNameExtensionFilter("MP3 File", "mp3"));
  jFC.setMultiSelectionEnabled(true);
  jFC.showOpenDialog(null);

  for (File f : jFC.getSelectedFiles()) {
    GetResponse response = client.prepareGet(INDEX_NAME, DOC_TYPE, f.getAbsolutePath()).setRefresh(true).execute().actionGet();
    if (response.isExists()) {
      continue;
    }

    song= minim.loadFile(f.getAbsolutePath());
    meta= song.getMetaData();

    Map<String, Object> doc = new HashMap<String, Object>();
    doc.put("author", meta.author());
    doc.put("title", meta.title());
    doc.put("path", f.getAbsolutePath());

    try {
      client.prepareIndex(INDEX_NAME, DOC_TYPE, f.getAbsolutePath())
        .setSource(doc).execute().actionGet();

      addItem(doc);
    } 
    catch(Exception e) {
      e.printStackTrace();
    }
  }
}


void controlEvent (ControlEvent evento) {
  vol = int(evento.getController().getValue());
  song.setGain(vol);
}


void fileSelected(File selection) {
  if (selection == null) {
    println("La ventana se cerró o el usuario precionó Cancelar.");
  } else {
    if (song!=null) {
      song.pause();
    }
    println("El usuairo eligió: " + selection.getAbsolutePath());

    song = minim.loadFile(selection.getAbsolutePath(), 1024);
    hP= new HighPassSP(300, song.sampleRate());
    song.addEffect(hP);
    lPF= new LowPassFS(300, song.sampleRate());
    song.addEffect(lPF);
    bP= new BandPass(300, 300, song.sampleRate());
    song.addEffect(bP);
    fft = new FFT(song.bufferSize(), song.sampleRate());
    fft.logAverages(22, 10);
    meta= song.getMetaData();
    if (!meta.title().equals("")) {
      texto.setText(meta.title()+"`\n"+meta.author());
      print("sale");
    } else {
      texto.setText(meta.fileName());
      print("entra");
    }
  }
}


void addItem(Map<String, Object> doc) {
  list.addItem(doc.get("author") + " - " + doc.get("title"), doc);
}


void playlist(int n) {
  if (song!=null) {
    song.pause();
  }

  Map<String, Object> value = (Map<String, Object>) list.getItem(n).get("value");
  println(value.get("path"));

  song= minim.loadFile((String)value.get("path"), 1024);
  hP = new HighPassSP(300, song.sampleRate());
  song.addEffect(hP);
  lPF = new LowPassFS(300, song.sampleRate());
  song.addEffect(lPF);
  bP = new BandPass(300, 300, song.sampleRate());
  song.addEffect(bP);
  fft = new FFT(song.bufferSize(), song.sampleRate());
  fft.logAverages(22, 10);
  meta= song.getMetaData();
  if (!meta.title().equals("")) {
    texto.setText(meta.title()+"`\n"+meta.author());
    print("sale");
  } else {
    texto.setText(meta.fileName());
    print("entra");
  }
}


void loadFiles() {
  try {
    SearchResponse response = client.prepareSearch(INDEX_NAME).execute().actionGet();

    for (SearchHit hit : response.getHits().getHits()) {
      addItem(hit.getSource());
    }
  } 
  catch(Exception e) {
    e.printStackTrace();
  }
}