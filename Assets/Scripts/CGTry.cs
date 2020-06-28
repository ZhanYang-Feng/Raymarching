using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class CGTry : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        
    }
    public void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, destination);
        RenderTexture.active = destination;
        GL.PushMatrix();
        GL.LoadOrtho();

        //_raymarchMaterial.SetPass(0);
        GL.Color(Color.blue);
        GL.Begin(GL.TRIANGLES);
        GL.Vertex3(0.25f, 0.25f, 0.0f);
        GL.Vertex3(0.25f, 0.35f, 0.0f);
        GL.Vertex3(0.35f, 0.25f, 0.0f);
        GL.End();
        

        GL.Begin(GL.QUADS);

        //BL
        GL.MultiTexCoord2(0, 0.0f, 0.0f);
        GL.Vertex3(0.0f, 0.0f, 1.0f);

        //BR
        GL.MultiTexCoord2(0, 1.0f, 0.0f);
        GL.Vertex3(1.0f, 0.0f, 1.0f);

        //TR
        GL.MultiTexCoord2(0, 1.0f, 1.0f);
        GL.Vertex3(1.0f, 1.0f, 1.0f);

        //TL
        GL.MultiTexCoord2(0, 0.0f, 1.0f);
        GL.Vertex3(0.0f, 1.0f, 1.0f);
        GL.End();

        GL.Color(Color.green);
        GL.Begin(GL.TRIANGLES);
        GL.Vertex3(0.35f, 0.25f, 0.0f);
        GL.Vertex3(0.35f, 0.35f, 0.0f);
        GL.Vertex3(0.45f, 0.25f, 0.0f);
        GL.End();

        GL.PopMatrix();
    }
}
